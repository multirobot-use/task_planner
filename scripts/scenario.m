%% Function to switch between handmade pre-defined scenarios or random generated scenarios with some constraints
function [Agent, Task] = scenario(A, T, types, discretized)
    % Randomly generated scenario: A robots, T Tasks (without counting the recharge task), "types" different types of robots
    % In case we call this function using a single input argument, A becomes the "predefined" scenario to select
    switch nargin
    case 1
        predefined  = A;
        discretized = 0;
        random = 0;
    case 3
        predefined  = 0;
        discretized = 0;
        random = 1;
    case 4
        predefined  = 0;
        discretized = not(not(sum(discretized)));
        random = not(sum(discretized));
    otherwise
        error('Invalid input');
    end

    % Check if the input arguments are valid
    if discretized || random
        % Number of Agents
        if A < 1
            error('There must be at least one agent');
        end

        % Number of Tasks
        if T < 1
            error('There must be at least one tasks apart from Recharge task');
        end

        % Number of types
        if types < 1
            error('There must be at least one type of robot');
        end

        % Recharge task will be the first
        R = 1;
    end

    % Generate random continuos scenario
    if random
        % Minimum flight time (s)
        Ft_min = 15*60;

        % Maximum flight time (s)
        Ft_max = 40*60;

        % Maximum flight time already consumed initially (s)
        Ft_0_max = 0.35 * Ft_min;

        % Traveling speed (m/s)
        ts = 5;

        % Safety area (m)
        x_min = -100; x_max = 100;
        y_min = -150; y_max = 150;
        z_min = 0;   z_max = 5;

        % Position of the Recharge station [x y z] (m)
        recharge_wp = [0 0 1];

        % Upper bound for the robots safety flight time (s)
        Ft_saf_max = 0;
        corners = [x_max y_max; x_min y_max; x_min y_min; x_max y_min];
        for corner = 1:4
            Ft_saf = norm([corners(1,:) z_max] - [recharge_wp(1) recharge_wp(2) recharge_wp(3)])/ts;
            if Ft_saf > Ft_saf_max
                Ft_saf_max = Ft_saf;
            end
        end
        Ft_saf_max = ceil(Ft_saf_max);

        % Generate Agents
        for i = 1:A
            Agent(i) = struct('name', ['Agent_{' num2str(i) '}'], 'type', randi(types), 'Ft', randi([Ft_min Ft_max]), 'Ft_0', randi([0 Ft_0_max]), 'Ft_saf', Ft_saf_max, 'ts', ts, 'P0', struct('x', randi([x_min x_max]), 'y', randi([y_min y_max]), 'z', 0));
        end

        % Minimum execution/flight time (s)
        Te_min = 3/4*Ft_min;

        % Maximum execution/flight time (s) for fragmentable tasks
        Te_max_f = 5/2 * Ft_max; % 250% of the Robots battery time
    
        % Maximum fragmentation loses (%)
        Fl_max = 0;

        % Generate Tasks
        Task(R) =  struct('name', 't_R', 'Hr', [1:types], 'Te', 5*60, 'tmax', 0, 'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', recharge_wp(1), 'y', recharge_wp(2), 'z', recharge_wp(3)), 'color', [0.85 0.33 0.10]);
        for i = 2:T+1
            % Create a flag to check if tasks are valid
            valid = false;

            while not(valid)
                % Set valid task to true
                valid = true;

                % Generate hardware requirements
                Hr = [];
                while ~any(ismember([Agent.type], Hr))
                    Hr = [];
                    for h = 1:types
                        if randi([0 1]) == 1
                            Hr = [Hr h];
                        end
                    end
                end

                % Generate N (number of required agents, 0 if not specified). Note that (N = 0) == (N = 1 Fragmentable)
                max_N = sum(ismember([Agent.type], Hr));
                N = randi([0 max_N]);

                % Generate N-hardness, Relayability and Fragmentability parameters
                if N == 0
                    N_hardness = 0;
                    Relayability = 0;
                    Fragmentability = 1;
                else
                    N_hardness = 0;%randi([0 1]);
                    Relayability = randi([0 1]);
                    if Relayability == 0
                        Fragmentability = randi([0 1]);
                    else
                        Fragmentability = 0;
                    end
                end
                % Non-decomposable: 12.5%
                % Relayable: 25%
                % Fragmentable: 50% + 12.5% = 62.5%

                % Generate Te depending in if the task is fragmentable or not
                if Fragmentability == 0 && Relayability == 0
                    aux_N = N;
                    if aux_N == 0
                        aux_N = 1;
                    end
                    aux_Ft = [Agent.Ft];
                    aux_type = [Agent.type];
                    % N agents are requested, so let's find the maximum Te the task could have to be assigned to N agents
                    while aux_N > 0
                        [aux_Te_max, idx] = max(aux_Ft .* ismember(aux_type, Hr));
                        if(aux_Te_max ~= 0)
                            Te_max = aux_Te_max;
                            % Remove the agent from the list
                            aux_Ft(idx) = [];
                            aux_type(idx) = [];
                            aux_N = aux_N - 1;
                        else
                            break;
                        end
                    end
                    Te = randi([Te_min Te_max - 2 * Ft_saf_max]);
                else
                    Te_max = Te_max_f;
                    Te = randi([Te_min Te_max_f]);
                end
                % Minimum/Maximum tmax (s) over the execution time
                tmax_min = ceil(1.2 * T * Te);
                tmax_max = 2 * T * Te_max;

                % Color
                color = [randi([0 255]) randi([0 255]) randi([0 255])]/255;
                % Make sure that the color isn't too dark to read black text over it
                while mean(color) < 0.6
                    color = [randi([0 255]) randi([0 255]) randi([0 255])]/255;
                end

                % Add task to the structure
                Task(i) =  struct('name', ['t_{' num2str(i-1) '}'], 'Hr', Hr, 'Te', Te, 'tmax', randi([tmax_min, tmax_max]), 'N', N, 'N_hardness', N_hardness, 'Relayability', Relayability, 'Fragmentability', Fragmentability, 'Fl', randi([0 Fl_max]), 'wp', struct('x', randi([x_min x_max]), 'y', randi([y_min y_max]), 'z', randi([z_min z_max])), 'color', color);

                if Task(i).Relayability
                    % Estimate task number of fragments and compatible robots
                    [~, Task_tmp, ~, ~, ~, ~, ~, ~, ~, ~] = getConstantScenarioValues(Agent, Task);

                    % Check if task is valid: Te(t)/nf > Te(R)
                    valid = Task_tmp(i).Te / Task_tmp(i).nf > Task_tmp(R).Te;
                end
            end
        end
    % Generate random discretized scenario
    elseif discretized
        % Robot's flight time (s)
        Ft = 20*60;

        % Maximum flight time already consumed initially (s)
        Ft_0 = [0 0.25 0.5] * Ft;

        % Traveling speed (m/s)
        ts = 5;

        % Safety area (m)
        x_min = -100; x_max = 100;
        y_min = -150; y_max = 150;
        z_min = 0;   z_max = 5;

        % Position of the Recharge station [x y z] (m)
        recharge_wp = [0 0 1];

        % Upper bound for the robots safety flight time (s)
        Ft_saf_max = 0;
        corners = [x_max y_max; x_min y_max; x_min y_min; x_max y_min];
        for corner = 1:4
            Ft_saf = norm([corners(1,:) z_max] - [recharge_wp(1) recharge_wp(2) recharge_wp(3)])/ts;
            if Ft_saf > Ft_saf_max
                Ft_saf_max = Ft_saf;
            end
        end
        Ft_saf_max = ceil(Ft_saf_max);

        % Generate Agents
        for i = 1:A
            Agent(i) = struct('name', ['Agent_{' num2str(i) '}'], 'type', randi(types), 'Ft', Ft, 'Ft_0', Ft_0(randi(length(Ft_0))), 'Ft_saf', Ft_saf_max, 'ts', ts, 'P0', struct('x', randi([x_min x_max]), 'y', randi([y_min y_max]), 'z', 0));
        end

        % Task execution time (s)
        Te_discrete = [0.35 1.25 2.5] * Ft;

        % Generate Tasks
        Task(R) =  struct('name', 't_R', 'Hr', [1:types], 'Te', 5*60, 'tmax', 0, 'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', recharge_wp(1), 'y', recharge_wp(2), 'z', recharge_wp(3)), 'color', [0.85 0.33 0.10]);
        for i = 2:T+1
            % Create a flag to check if tasks are valid
            valid = false;
            
            while not(valid)
                % Set valid task to true
                valid = true;

                % Generate hardware requirements
                Hr = [];
                while ~any(ismember([Agent.type], Hr))
                    Hr = [];
                    for h = 1:types
                        if randi([0 1]) == 1
                            Hr = [Hr h];
                        end
                    end
                end

                % Maximum number of required agents (0 if not specified). Note that (N = 0) == (N = 1 && Fragmentable)
                max_N = sum(ismember([Agent.type], Hr));

                % Generate execution time (later will be set to short if the task is non-decomposable)
                Te = Te_discrete(randi(length(Te_discrete)));

                % Decomposability: Non-decomposable, Relayable, Fragmentable
                switch randi(3)
                case 1 % Non-decomposable
                    Relayability = 0;
                    Fragmentability = 0;
                    Te = Te_discrete(1);
                case 2 % Relayable
                    Relayability = 1;
                    Fragmentability = 0;
                    % If there is only one compatible robot, it should be able to execute the task without using relays
                    % Else, if the randomly selected execution time is longer than the robots flight time minus the safety flight time, we would need at least one of the compatible robots to perform relays
                    % Else, no need to do nothing
                    % Note: with the correct amount of maximum fragments for a task, one extra robot is enough to perform the needed relays to the rest in a multi-robot fragmentable task
                    if max_N == 1
                        % Switch randomly selected execution time to the shortest one
                        Te = Te_discrete(1);
                    
                    elseif Te > Ft - 2 * Ft_saf_max
                        % Reduce the upper bound for N in one unit
                        max_N = max_N - 1;
                    end
                case 3 % Fragmentable
                    Relayability = 0;
                    Fragmentability = 1;
                end

                % Generate N (later will be set to 0 if coalition flexibility is unspecified)
                N = randi(max_N);

                % Coalition flexibility: N-hard, N-soft, N-unspecified
                switch randi(3)
                case 1 % N-hard
                    N_hardness = 1;
                case 2 % N-soft
                    N_hardness = 0;
                case 3 % Unspecified
                    N_hardness = 0;
                    N = 0;
                    % Unspecified tasks are treated as fragmentable tasks
                    Relayability = 0;
                    Fragmentability = 1;
                end

                % Color
                color = [randi([0 255]) randi([0 255]) randi([0 255])]/255;
                % Make sure that the color isn't too dark to read black text over it
                while mean(color) < 0.6
                    color = [randi([0 255]) randi([0 255]) randi([0 255])]/255;
                end

                % Add task to the structure
                Task(i) =  struct('name', ['t_{' num2str(i-1) '}'], 'Hr', Hr, 'Te', Te, 'tmax', T*Te_discrete(3), 'N', N, 'N_hardness', N_hardness, 'Relayability', Relayability, 'Fragmentability', Fragmentability, 'Fl', 0, 'wp', struct('x', randi([x_min x_max]), 'y', randi([y_min y_max]), 'z', randi([z_min z_max])), 'color', color);

                if Task(i).Relayability
                    % Estimate task number of fragments and compatible robots
                    [~, Task_tmp, ~, ~, ~, ~, ~, ~, ~, ~] = getConstantScenarioValues(Agent, Task);

                    % Check if task is valid: Te(t)/nf > Te(R)
                    valid = Task_tmp(i).Te / Task_tmp(i).nf > Task_tmp(R).Te;
                end
            end
        end
    % Load predefined scenario
    elseif predefined
        if not(isnumeric(A))
            if not(isequal(A, 'ros_simulation'))
                old_executed_random_scenario_id = A;
                load(['../mat/Agent_', old_executed_random_scenario_id, '.mat']);
                load(['../mat/Task_', old_executed_random_scenario_id, '.mat']);
            else
                % Scenario to use in the ROS demo
                Agent(1) = struct('name', 'uav1', 'type', 1, 'Ft', 30*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y',  0, 'z', 0));
                Agent(2) = struct('name', 'uav2', 'type', 2, 'Ft', 30*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y',  2, 'z', 0));
                Agent(3) = struct('name', 'uav3', 'type', 3, 'Ft', 30*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', -2, 'z', 0));

                Task(1) = struct('name', 't_R',                    'Hr', [1, 2, 3], 'Te', 2*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 'PVArrayInspectionShort', 'Hr', [1],       'Te',  5*60, 'tmax', 60*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 'Monitoring',             'Hr', [1 2],     'Te', 15*60, 'tmax', 60*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 'PVArrayInspectionLong',  'Hr', [3],       'Te', 25*60, 'tmax', 60*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -6,  'y',  10, 'z', 2), 'color', [0.93 0.69 0.13]);
            end
        else
            if length(A) > 1
                error('Invalid input');
            end
            
            predefined = A;

            switch predefined
            case 0
                error('To generate random scenarios call scenario() using 3 input arguments: A, T, types');

            case 1
                % Scenario 1: Hardware compatibility: 2 tasks (Nr = 1) of the same type and two agents but only one of them is compatible
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 2, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1 2], 'Te', 5*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1],   'Te', 5*60, 'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1],   'Te', 5*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 2
                % Scenario 2: Hardware compatibility: first 2 tasks (Nr = 1) of the same type and two agents, both compatible.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 2, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1 2], 'Te', 5*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1 2], 'Te', 5*60, 'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1 2], 'Te', 5*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 3
                % Scenario 3: Recharges allowed: 2 agents and 3 non-decomposable tasks.
                % One of the agents has initially consumed almost all his flight time, and the other has plenty of flight time left.
                % One of the tasks should be short enough to be executed by the first agent without recharging. If recharges are allowed, we should see how the first agent recharges and then execute at least one long task. If recharges are not allowed, we should see the second agent executing both long tasks and the fisrt, only the short task, resulting in a longer makespan.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 60*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 18*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 20*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 't_3', 'Hr', [1], 'Te', 20*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.93 0.69 0.13]);
            case 4
                % Scenario 4: N-hardness: 2 Agents, 1 task with Nr = 1, other with Nr soft = 2, and other with Nr hard = 2.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60, 'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 6*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 't_3', 'Hr', [1], 'Te', 7*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.93 0.69 0.13]);
            case 5
                % Scenario 5: Relays allowed: 2 agents, 2 tasks, the longest of them, decomposable.
                % One agent has enough battery to perform the short task or a third of the decomposable task.
                % The other agent has battery enough to perform the whole long task, but it has initially consumed just enough battery to only be able to carry out two thirds of the long task.
                % Remember to make the recharge execution time big enough to make the makespan significantly longer.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 11*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -70, 'y',  80,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 20*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -80, 'y',  90,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 6
                % Scenario 6: Relays not-allowed: 2 agents, 2 tasks, the longest of them, decomposable.
                % One agent has enough battery to perform the short task or a third of the decomposable task.
                % The other agent has battery enough to perform the whole long task, but it has initially consumed just enough battery to only be able to carry out two thirds of the long task.
                % Remember to make the recharge execution time big enough to make the makespan significantly longer.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 8*60,  'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 9*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -70,  'y',  80,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 20*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -80,  'y',  90,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 7
                % Scenario 7: Synchronizations: 2 agents and 2 tasks. One task with Nr = 1, and the other with Nr = 2.
                % We should see how the second task is executed in parallel by both agents, and how one of the agents waits for the other to finish the first task.
                % Make the task with Nr = 1 to have a short deadline to make it to be executed first.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 40*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 40*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 8*60,  'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 20*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 8
                % Scenario 8: Fragmentable N-hard task: 1 agents, 1 fragmentable task with Nr = 2, and make the agents need to recharge at least once in between.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 12*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 100, 'y', 150, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', -100, 'y', -150, 'z', 5));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  100,  'y',  150,  'z', 0), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 30*60, 'tmax', 60*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', 100,  'y',  150,  'z', 0), 'color', [0.00 0.45 0.74]);
            case 9
                % Scenario 9: Relay: 3 agents, 1 relayable task with Nr = 2 that need to be relayed once or twice.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 8*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 10*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 40*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 25*60, 'tmax', 30*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 10
                % Scenario 10: N-hardness: like 4 but now with an extra task with hard N = 1.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 40*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 40*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60, 'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 6*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 't_3', 'Hr', [1], 'Te', 7*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.93 0.69 0.13]);
                Task(5) = struct('name', 't_4', 'Hr', [1], 'Te', 8*60, 'tmax', 50*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.45 0.00 0.74]);
            case 11
                % Scenario 11: 2 Agents (2 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test synchronization and relays. N-hard, N-soft, Relayable, Non-relayable
                % Here there's no specific characteristic to test. We may see a waiting time to syncrhonize the task_2 execution, or we may see that na(t_2) = 1
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 55*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 15*60, 'Ft_0', 10*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 152*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,   'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 5*60,   'tmax', 50*60, 'N', 2, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 12
                % Scenario 12: 3 Agents (3 type 1), 4 Tasks (Recharge, Task_1, Task_2, Task_3)
                % Test N hardness
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 30*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 2*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 15*60, 'tmax', 45*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 15*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 't_3', 'Hr', [1], 'Te', 15*60, 'tmax', 60*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -6,  'y',  10, 'z', 2), 'color', [0.93 0.69 0.13]);
            case 13
                % Scenario 13: 2 Agents (2 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test if we can remove T dimension from synchronization and relays variables. Check if both implementations return the same results and if the use of memory is better.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 25*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 15*60, 'Ft_0', 10*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 26*60, 'tmax', 45*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 10*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 14
                % Scenario 14: 2 Agents (2 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test checkSolution function in a scenario with crossed relays (no solution). A task longer than the other. Drawing 1.R (A1:T1,T2; A2:T2,T1) and Drawing 2 (A1:T1; A2:T1,T2,R,T1).
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 25*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 15*60, 'tmax', 25*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 15
                % Scenario 15: 2 Agents (2 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test checkSolution function in a scenario with unfeasible relays (no solution). Short task to relay with long tasks in between. Drawing 3 (A1:T1,T3,R,T1; A2:T1,T2,R,T1).
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 2*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 5*60,  'tmax', 35*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 15*60, 'tmax', 35*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
                Task(4) = struct('name', 't_3', 'Hr', [1], 'Te', 20*60, 'tmax', 35*60, 'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.93 0.69 0.13]);
            case 16
                % Scenario 16: 3 Agents (3 type 1), 2 Tasks (Recharge, Task_1)
                % test Fragmentable tasks with specified N
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 6*60,  'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 7*60,  'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 15*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 17
                % Scenario 17: 3 Agents (3 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test new synch and relays code
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 7*60,  'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 7*60,  'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 15*60, 'tmax', 50*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 15*60, 'tmax', 50*60, 'N', 3, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -8,  'y',  9,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 18
                % Scenario 18: 5 Agents (5 type 1), 3 Tasks (Recharge, Task_1, Task_2)
                % Test fragmentable tasks with specified N.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 10*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 2, 'y', 2, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 10*60, 'Ft_0', 6*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 3, 'y', 3, 'z', 0));
                Agent(4) = struct('name', 'Agent_4', 'type', 1, 'Ft', 10*60, 'Ft_0', 1*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 4, 'y', 4, 'z', 0));
                Agent(5) = struct('name', 'Agent_5', 'type', 1, 'Ft', 10*60, 'Ft_0', 3*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 5, 'y', 5, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10] );
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 15*60, 'tmax', 50*60, 'N', 4, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 5*60,  'tmax', 6*60,  'N', 3, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  3,  'y',  5,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 19
                % Scenario 19: test unspecified N. We should see how t_1 is fragmented in two and executed simultaneously in both agents.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 25*60, 'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 20
                % Scenario 20: test Fragmentable task with fixed N. We should see how t_1 is fragmented in two and executed simultaneously by two grups of two agents.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(4) = struct('name', 'Agent_4', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 25*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 21
                % Scenario 21: test Fragmentable task with fixed N. We should see how t_1 is fragmented in two and executed simultaneously by two grups of two agents.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 15*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 20*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(4) = struct('name', 'Agent_4', 'type', 1, 'Ft', 20*60, 'Ft_0',  0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 25*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 22
                % Scenario 22: test Fragmentable task with fixed N. There is one extra task to unsincronise the groups. We should see how t_1 is fragmented in two and executed simultaneously by two grups of two agents.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(4) = struct('name', 'Agent_4', 'type', 1, 'Ft', 20*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 25*60, 'N', 2, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1], 'Te', 5*60,  'tmax', 6*60,  'N', 1, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  3,  'y',  5,  'z', 2), 'color', [0.47 0.67 0.19]);
            case 23
                % Scenario 23: test unspecified N. We should see how t_1 is fragmented in three and executed asynchronously in both agents.
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 10*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 10*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 25*60, 'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
            case 24
                % Scenario 24: 3 Agents (3 type 1), 4 Tasks (Recharge, Task_1, Task_2, Task_3)
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 14*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 14*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(3) = struct('name', 'Agent_3', 'type', 1, 'Ft', 60*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));

                Task(1)  = struct('name', 't_R', 'Hr', [1], 'Te', 7*60,  'tmax', 0,    'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.85 0.33 0.10]);
                Task(2)  = struct('name', 't_1', 'Hr', [1], 'Te', 30*60, 'tmax', 90*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 200, 'z', 0), 'color', [0.00 0.45 0.74]);
                Task(3)  = struct('name', 't_2', 'Hr', [1], 'Te', 30*60, 'tmax', 90*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', -100, 'y', 100, 'z', 0), 'color', [0.47 0.67 0.19]);
                Task(4)  = struct('name', 't_3', 'Hr', [1], 'Te', 30*60, 'tmax', 90*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 250, 'y', 50, 'z', 0), 'color', [0.93 0.69 0.13]);
            case 25
                % Scenario 25: Te 20 min, 3 min battery residue, nf = 20, 3 consecutive fragments. F_saf = 0 for demo purposes
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 10*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));

                Task(1)  = struct('name', 't_R', 'Hr', [1], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.85 0.33 0.10]);
                Task(2)  = struct('name', 't_1', 'Hr', [1], 'Te', 20*60, 'tmax', 90*60, 'N', 1, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.00 0.45 0.74]);
                Task(3)  = struct('name', 't_2', 'Hr', [1], 'Te', 14*60,  'tmax', 90*60, 'N', 1, 'N_hardness', 0, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.47 0.67 0.19]);
            case 26
                % Scenario 26: Te 20 min, 3 min battery residue, nf = 20, 3 consecutive fragments. F_saf = 0 for demo purposes
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 25*60, 'Ft_0', 0*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 1, 'Ft', 50*60, 'Ft_0', 50*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));

                Task(1)  = struct('name', 't_R', 'Hr', [1], 'Te',  5*60, 'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.85 0.33 0.10]);
                Task(2)  = struct('name', 't_1', 'Hr', [1], 'Te',  7*60, 'tmax', 90*60, 'N', 1, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.00 0.45 0.74]);
                Task(3)  = struct('name', 't_2', 'Hr', [1], 'Te', 10*60, 'tmax', 90*60, 'N', 1, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.93 0.69 0.13]);
                Task(4)  = struct('name', 't_3', 'Hr', [1], 'Te', 30*60, 'tmax', 90*60, 'N', 1, 'N_hardness', 0, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0, 'wp', struct('x', 0, 'y', 0, 'z', 0), 'color', [0.47 0.67 0.19]);
            otherwise
                % Default scenario: 2 Agents (1 type 1, 1 type 2), 6 Tasks (Recharge, Task_1, Task_2, Task_3, Task_4, Task_5)
                Agent(1) = struct('name', 'Agent_1', 'type', 1, 'Ft', 20*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 0, 'y', 0, 'z', 0));
                Agent(2) = struct('name', 'Agent_2', 'type', 2, 'Ft', 25*60, 'Ft_0', 5*60, 'Ft_saf', 0, 'ts', 5, 'P0', struct('x', 1, 'y', 1, 'z', 0));

                Task(1) = struct('name', 't_R', 'Hr', [1 2], 'Te', 5*60,  'tmax', 0,     'N', 0, 'N_hardness', 0, 'Relayability', 0, 'Fragmentability', 0, 'Fl', 0,  'wp', struct('x',  0,  'y',  0,  'z', 1), 'color', [0.85 0.33 0.10]);
                Task(2) = struct('name', 't_1', 'Hr', [1],   'Te', 15*60, 'tmax', 45*60, 'N', 2, 'N_hardness', 1, 'Relayability', 1, 'Fragmentability', 0, 'Fl', 0,  'wp', struct('x', -7,  'y',  8,  'z', 2), 'color', [0.00 0.45 0.74]);
                Task(3) = struct('name', 't_2', 'Hr', [1 2], 'Te', 25*60, 'tmax', 30*60, 'N', 1, 'N_hardness', 1, 'Relayability', 0, 'Fragmentability', 1, 'Fl', 0,  'wp', struct('x',  13, 'y', -2,  'z', 2), 'color', [0.47 0.67 0.19]);
            end
        end
    else
        error('Invalid input');
    end
end
