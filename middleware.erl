-module(middleware).
-export([start/0,
		 init_agent/2,
		 master_agent_loop/2,
		 empty_computation_loop/1,
		 print_list/1]).


print_list([ H ]) -> io:format("~p ~n", [H]), ok;
print_list([ H | T ]) -> 
	io:format("~p ~n", [H]),
	print_list(T), ok.

% At the beginning we have master agent 
start() ->
	% Master agent starts here
	MyPid = self(),
	register(master_node_1, MyPid),
	io:format("Here is our entry point initialized ~p~n", [MyPid]),
	% Here it initializes the corresponding computing unit
	ComputingUnit = init_agent(MyPid, []),
	io:format("Corresponding computing unit ~p~n", [ComputingUnit]),
	register(comp_node_1, ComputingUnit),
	net_adm:ping(comp_node_1),
	% io:format("List of nodes master (~p) is connected to: ~n", [ComputingUnit]),
	% Nodes = nodes(),
	% print_list(Nodes),
	master_agent_loop(ComputingUnit, []).
	
init_agent(AgentPid, AgentsAlive) -> 
	spawn(middleware, empty_computation_loop, [AgentPid]). 

master_agent_loop(ComputingUnit, AgentsAlive) -> 
	master_agent_loop(ComputingUnit, AgentsAlive).
	
empty_computation_loop(AgentPid) ->
	empty_computation_loop(AgentPid).

local_agent_loop() -> 
	local_agent_loop().

% add_node(Pid) -> .



