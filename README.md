# Optimal Task Allocation for Heterogeneous Multi-robot Teams with Battery Constraints
## Overview
This repository deals with optimal task planning missions with heterogeneous teams of robots that will have to execute a number of tasks that may have different specifications and types, while dealing with limited resources that can be recovered by executing certain actions, i.e. the robots have limited battery power, but have the possibility to plan recharges.

The objective is to find a mission plan, i.e. to assign all tasks to the robots (also called agents) needed to complete them successfully respecting the constraints imposed by each task, while minimizing the total execution time, i.e. the makespan.

The problem is formulated using Mixed Integer Linear Programming (MILP) in Matlab. To solve it, the `intlinprog()` Matlab function is called. If you have Gurobi installed in Matlab, this function should be overwritten by the `intlinprog()` Gurobi function, so the same code works using Matlab or Gurobi solvers.

## Problem description
The proposed problem constitutes a first step towards the formulation and analysis of a problem of complexity never before addressed in the state of the art.

The problem can be classified as ST-MR-TA according to the taxonomy described in [[1]](#1), i.e., robots can execute only one task at a time (ST), tasks may need more than one robot to execute (MR), and robots are assigned tasks to be executed according to a schedule. Can also be classified as Task Windows (TW) according to [[2]](#2). There's also another category in that taxonomy, Synchronization and Precedence (SP). We do not have precedence constraints, but we do have synchronization constraints when multiple robots has to execute a task together or do a relay due to battery constraints. Last, this problem can be classified also as CD according to [[3]](#3), i.e. the tasks has complex inter-task dependencies.

Robots are mainly characterized by their type. Tasks have a list of robot types that have hardware compatible with it. In this way, the formulation can restrict the assignment of tasks to task-compatible robots only, being totally agnostic to the actual hardware that constitutes each type of robot.

To understand the wide variety of tasks that are contemplated within the problem, we talk about two characteristics of the tasks: composability and number of robots. Depending on the composability, tasks can be non-decomposable, relayable or fragmentable. Non-composable tasks must be executed continuously by the same robots, relayable tasks must be executed continuously, but allow relays between several robots, and finally, fragmentable tasks can be executed in fragments that do not have to be coordinated between them and can be spread over the schedule of one or several robots. On the other hand, tasks can have a fixed number of robots, i.e. they need to be executed by exactly the specified number of robots, they can have a variable number of robots, meaning that they specify an ideal number of robots with which to be executed, but allow a different number of robots to be used, or they can specify no number of robots at all, and their duration will depend on the number of robots finally employed to execute them. Tasks can belong to any type that is a combination of these two characteristics.

In the [scenario](scripts/scenario.m) script you can see in more detail how agents (robots) and tasks are implemented within the formulation.

## Installation
There are no special requirements to be able to run the formulation Matlab script.
Just make sure you have correctly added this project's path to the matlab path, including subfolders:
```
addpath(genpath('<install_dir>/task_planner'))
```
You may also want to install [Gurobi](https://www.gurobi.com/) for Matlab to use it as MILP solver.

## Execution
The main script, which implements and solves the MILP formulation, is [optimalTaskAllocator](src/optimalTaskAllocator.m).
Inside this file there is a function defined as:
```
function [sol, fval] = optimalTaskAllocator(scenario_id, execution_id, scenario_size, objective_function, formulation_variants_flags, config_flags, solver_config)
```
First, the `scenario_id` parameter should be numeric if we want to solve a manually predefined [scenario](scripts/scenario.m), `0` if we want to solve a randomly generated scenario, and should be a string if we want to solve a saved scenario. In this last case `scenario_id` should be the ID name string of the saved scenario.

Second, the `execution_id` parameter is a string, used in the log file and as file suffix to save the scenario information.

Third, the `scenario size` parameter is a 1x3 vector with the number of robots (A), number of tasks (T) (without counting the recharge task) and number of different types of robots (types). This is used only when we want to solve a randomly generated scenario (`scenario_id == 0`), otherwise, this parameter can be set to an empty array.

`objective_function` is an integer parameter that allows us to choose between different predefined objective functions to minimize. The details about the different options can be found commented in the source file.

Then, optionally, `formulation_variants_flags` parameter allows us to modify the problem to solve a scenario with a slightly different MILP formulation. It's a 1x4 logic vector corresponding to the following flags: `[recharges_allowed_flag, relays_allowed_flag, fragmentation_allowed_flag, variable_number_of_robots_allowed_flag]`. We can set this parameter to an empty array to use default config: the complete formulation. 

Last, `config_flags` parameter is a 1x9 logic vector corresponding to the following option flags: `[solve_flag, initialize_flag, genetic_algorithm_solver, print_solution_flag, display_flag, log_file_flag, save_flag, test_flag, recovery_flag]`. The default configuration is used if this is set to an empty array.

In this way, we can run the planner to solve a ramdomly generated scenario with `3` robots, `2` tasks and `1` defferent
type of robot like:
```
[sol, fval] = optimalTaskAllocator(0, 'random', [3 2 1]);
```
By default, the print solution flag is set to false. To change that we need to specify it in the last parameter:
```
[sol, fval] = optimalTaskAllocator(0, 'random', [3 2 1], [], [], [1 1 0 0 0 0 0]);
```
If the scenario is feasible, we would see the optimal solution displayed in a bar plot like this:

![random3x2](https://github.com/multirobot-use/task_planner/assets/74324102/cc9a8771-5bb3-42b3-a7db-ae48c7c4df03)

Note that the bar for each task is divided into two parts. The upper part represents the total duration of the task. We can see that the task name/id appears above it. The length of the lower part represents what part of task time corresponds to the travel time, waiting time and execution time.

To solve a predefined scenario (for example scenario `1`), and moreover to do so with a different objective function and with a variant of the formulation, we can run it like:
```
[sol, fval] = optimalTaskAllocator(1, 'Test', [], 4, [1 0 0 0], []);
```
Here we are running the mission planner with the fourth predefined objective function and a variant where only recharge are allowed. Task are not fragmentable nor decomposable, and the coalition size flexibility is always hard.

Last, we can use the `genetic_algorithm_solver` configuration parameter to solve the MILP problem using [Matlab's GA solver](https://es.mathworks.com/help/gads/ga.html) from the Optimization Toolbox.
```
config_flags = [1, 0, 1, 1, 1, 0, 0, 0, 0];
[sol, fval] = optimalTaskAllocator(scenario_id, execution_id, [], objective_function, [], config_flags, 0);
```
While running, you should be able to see a plot like this:

<img src="https://github.com/alvcalmat/XATS/assets/74324102/4c577bf4-cb13-461c-839b-733d2a0f05d7" width="600"/>

To know more about GA solver options go to [Genetic Algorithm Options](https://es.mathworks.com/help/gads/genetic-algorithm-options.html)

### Analyzing the solution
After running the `optimalTaskAllocator()` function, we can check the values of some variables of the solution vector using the [getVarValue](scripts/getVarValue.m) script. To do so, we first need to load the information about the scenario that has just been solved:

**Note**: if it was a randomly generated scenario, remember to set the save flag on before when calling the main function.
```
[Agent, Task] = scenario(scenario_id);
```
Where `scenario_id` is the id of the scenario just solved.

Now the `Agent` and `Task` structures with the scenario information are loaded.

With this information and the solution vector returned by the `optimalTaskAllocator()`, we can call `getVarValue()` to check the value of any decision variable that we want. To check for example how mane fragments are tasks being divided into:
```
nf_t = getVarValue(sol, Agent, Task, 'nf_t')
```
**Note**: one of the tasks will be the recharge task, usually the first task.

The names of the variables can be consulted in the [getVarValue](scripts/getVarValue.m) source code.

In case that we forgot to print the solution, we can also print it manually after loading the planner workspace information doing:
```
printSolution(sol, Agent, Task, 0, 'scenario_id', 'execution_id', fval);
```

## Heuristic planner
The heuristic planner creates, if feasible, a solution to the specified scenario. This algorithm is contained in [initializer](src/initializer.m) and its defined as:
```
function [Agent, Task, allocation_order, S_R] = initializer(arg_1, arg_2, reward_coefficients, version, seed)
```
This heuristic method can be used to initialize the MILP solver by setting the corresponding config flag at launching time. To separately call `initializer()`, `arg_1` and `arg_2` should either be Agent and Task or a valid scenario id and optionally execution id. The second parameter, `reward_coefficients`, controls the task allocation order. `version` is used to select the method to get the task allocation order. Last, `seed` is used as allocation order in the "seed" version (input order).
The solution to the specified scenario is added to `Agent` and `Tasks` structures. `allocation_order` output variable can be used as seed to regenerate the solution using the initializer with the "seed" version, and `S_R` output variable indicates the coordination points, needed if we want to build the complete solution array.

## Build solution
This is a tool to build the decision variable array from a handmade or heuristic solution. Its defined as follows:
´´´
function [dv, fval, result] = buildSolutionArray(handmade_solution, Agent, Task, objective_function, scenario_id, print_coord_steps_flag)
´´´
The minimum required inputs are either a handmade solution, with the key decision variables (task allocation, task fragmentation, and coordination points) and/or `Agent` and `Task` structures from the heuristic planner.
Note: `Result` is false if the handmade solution is incorrect, true otherwise.

**Note** that there may be more that one optimal solution, and as a consequence of that, the showed solution may be an equivalent solution to the one founded by the solver. Mainly, the tasks where the coordination waiting times are applied may change.

## Check solution
This tool checks if an array solution fits constraints. [checkSolution](scripts/checkSolution.m) can be used either to check if the result if correct and whether any of the soft constraints are being broken. 

To see an example, lets say we want to build and check if a handmade solution for the predefined scenario number `5` is valid or not. The first step would be to load into the workspace the scenario information:
```
[Agent, Task] = scenario(5);
[Agent, Task, A, T, S, N, R, Td_a_t_t, Te_t_nf, H_a_t] = getConstantScenarioValues(Agent, Task);
```

Then we need to build the solution itself and put the main decision variables into a vector:
```
% Build x(a,t,s) by hand
xats = zeros(A,(T+1),(S+1));

% Initial tasks
t = 0;
s = 0;
xats(:, t + 1, s + 1) = 1;

% Agent 1
a = 1;
tasks = [2, 0, 2];
s = 0;
for task = 1:length(tasks)
    t = tasks(task);
    s = s + 1;
    xats(a, t + 2, s + 1) = 1;
end

% Agent 2
a = 2;
tasks = [1, 2];
s = 0;
for task = 1:length(tasks)
    t = tasks(task);
    s = s + 1;
    xats(a, t + 2, s + 1) = 1;
end

xats = reshape(xats,1,[]);

% nf(t) by hand
nf_t = 1 * ones(1,T);
nf_t(2 + 1) = 3;

% S by hand: for each slot, the number of synchronizations should be ns(t,a1,s1) = (na(t) - 1) * x(a1,t,s1)
Sta1s1a2s2 = zeros(T-1,A,S,A,S);
Sta1s1a2s2 = reshape(Sta1s1a2s2,1,[]);

% R by hand: the total number of relays per task should be nr(t) = n(t) - na(t)
Rta1s1a2s2 = zeros(T-1,A,S,A,S);
Rta1s1a2s2(2, 1,  1, 2,  2) = 1;
Rta1s1a2s2(2, 2,  2, 1,  3) = 1;
Rta1s1a2s2 = reshape(Rta1s1a2s2,1,[]);

% xats_nf_S_R
xats_nf_S_R = [xats nf_t Sta1s1a2s2 Rta1s1a2s2];
```

Note that `xats` is the task allocation itself. `x(a,t,s) = 1` if task `t` is assigned to slot `s` of robot `a`, `0` otherwise. `nf(t)` is the numbers of fragments that task `t` is divided into. Last `S(t, a1, s1, a2, s2)` and `R(t, a1, s1, a2, s2)` are the synchronization and relays variables, `1` if there is a coordination between a fragment of task `t` allocated in slot `s1` of agent `a1` and a fragment of task `t` assigned to slot `s2` of agent `a2`, `0` otherwise.

Then, we need to call the `buildSolutionArray()` function:
```
[sol, fval, result_bld] = buildSolutionArray(xats_nf_S_R, Agent, Task)
```

Last, we need to call the `checkSolution()` function:
```
[result_chk] = checkSolution(sol, Agent, Task);
```

If both `result_bld` and `result_chk` are true, we can visualize the solution with:
```
printSolution(sol, Agent, Task);
```

![scenario5](https://github.com/multirobot-use/task_planner/assets/74324102/8c906833-db7f-49fa-91f6-fcf2c05176f7)

## References
<a id="1">[1]</a>
Gerkey, Brian P and Mataric, Maja J,
"A formal analysis and taxonomy of task allocation in multi-robot systems",
The International Journal of Robotics Research, vol. 23, no. 9, pp. 939–954, 2004.

<a id="2">[2]</a>
E. Nunes, M. Manner, H. Mitiche, and M. Gini,
“A taxonomy for task allocation problems with temporal and ordering constraints”,
Robotics and Autonomous Systems, vol. 90, pp. 55–70, 2017.

<a id="3">[3]</a>
G. A. Korsah, A. Stentz, and M. B. Dias,
“A comprehensive taxonomy for multi-robot task allocation”,
The International Journal of Robotics Research, vol. 32, no. 12, pp. 1495–1512, 2013.
