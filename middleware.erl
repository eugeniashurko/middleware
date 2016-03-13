-module(middleware).
-export([start/0,
		 init_comp_unit/1,
		 init_local_agent/2,
		 master_agent_loop/2,
		 empty_computation_loop/1,
		 print_list/1,
		 add_node/1,
		 local_agent_loop/3,
		 connect_local_agents/2,
		 stop_cluster/1,
		 stop_nodes/1,
		 pop_node/1,
		 remove_node/2
		 % stop_computing_unit/1,
		 % inform_local_agents/1
		]).


print_list([ H ]) -> io:format("~p ~n", [H]), ok;
print_list([ H | T ]) -> 
	io:format("~p ~n", [H]),
	print_list(T).

% At the beginning we have master agent 
start() ->
	% Master agent starts here
	MyPid = self(),
	register(master_node, MyPid),
	io:format("Here is our entry point initialized ~p~n", [MyPid]),
	io:format("Registered under name: ~p~n", [master_node]),
	% Here it initializes the corresponding computing unit
	ComputingUnit = init_comp_unit(MyPid),
	register(master_comp_node, ComputingUnit),
	io:format("Corresponding computing unit ~p~n", [ComputingUnit]),
	master_agent_loop(ComputingUnit, []).
	
init_local_agent(Master, AgentsAlive) ->
	ComputingUnit = init_comp_unit(self()),
	Name = list_to_atom(lists:flatten(io_lib:format("comp_node_~p", [node_id(AgentsAlive)]))),
	register(Name, ComputingUnit),
	io:format("with computing unit at ~p ~n", [ComputingUnit]),
	local_agent_loop(ComputingUnit, Master, AgentsAlive).

init_comp_unit(AgentPid) -> 
	spawn(middleware, empty_computation_loop, [AgentPid]). 

master_agent_loop(ComputingUnit, AgentsAlive) -> 
	receive
		add -> 
			NewPid = spawn(middleware, init_local_agent, [self(), AgentsAlive]),
			Name = list_to_atom(lists:flatten(io_lib:format("node_~p", [node_id(AgentsAlive)]))),
			register(Name, NewPid),
			io:format("New agent on ~p initialized ~n", [NewPid]),
			io:format("Registered under name: ~p~n~n", [Name]),
			% connect all other local agents to the new node
			connect_local_agents(NewPid, AgentsAlive),
			% now we add the new agent to the list of agents alive
			master_agent_loop(ComputingUnit, [NewPid | AgentsAlive]);
		stop -> 
			io:format("Stopping the cluster...~n", []),
			io:format("-----------------------~n", []),
			stop_nodes(AgentsAlive),
			unregister(master_node),
			unregister(master_comp_node),
			io:format("Stopped ~p~n", [master_node]);
		pop -> 
			% now we just remove last added node - 
			% but later maybe we will remove the node
			% by some criteria - least loaded etc
			Node = lists:last(AgentsAlive),
			Node ! stop,
			% inform_local_agents(Node),
			Name = list_to_atom(lists:flatten(io_lib:format("node_~p", [node_id(AgentsAlive)]))),
			unregister(Name)
		% { remove, Pid } ->
	end,
	master_agent_loop(ComputingUnit, AgentsAlive).

% TODO: Later when the nodes can be remote - add ping and all this things
connect_local_agents(_, []) -> ok;
connect_local_agents(NewPid, [ Agent ]) ->
	Agent ! {connect, NewPid},
	io:format("conneced to  ~p~n~n", [Agent]),
	ok;
connect_local_agents(NewPid, [ Agent | T ]) ->
	Agent ! {connect, NewPid},
	io:format("conneced to  ~p~n", [Agent]),
	connect_local_agents(NewPid, T).

empty_computation_loop(AgentPid) ->
	empty_computation_loop(AgentPid).

local_agent_loop(ComputingUnit, Master, AgentsAlive) -> 
	receive
		{ connect, NewPid } ->
			local_agent_loop(ComputingUnit, Master, [NewPid | AgentsAlive]);
		stop -> 
			{ _, Name } = process_info(ComputingUnit, registered_name),
			unregister(Name),
			ok
	end,
	local_agent_loop(ComputingUnit, Master, AgentsAlive).

add_node(Pid) -> 
	Pid ! add.

stop_nodes([]) -> ok;
stop_nodes([Agent]) ->
	Agent ! stop,
	{ _, Name } = process_info(Agent, registered_name),
	unregister(Name),
	io:format("Stopped ~w~n", [Name]);
stop_nodes([Agent | T]) ->
	Agent ! stop,
	{ _, Name } = process_info(Agent, registered_name),
	unregister(Name),
	io:format("Stopped ~w~n", [Name]),
	stop_nodes(T).

stop_cluster(Pid) ->
	Pid ! stop.

% util for generating the tokens to register the processes
node_id([]) -> 1;
node_id([_]) -> 2;
node_id([_ | T]) -> 1 + node_id(T).

pop_node(Master) ->
	Master ! { pop }.

remove_node(Master, Pid) ->
	Master ! { remove, Pid }.

% inform_local_agents() ->.
% stop_computing_unit()