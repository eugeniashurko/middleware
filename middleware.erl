-module(middleware).
-export([start/0,
		 init_comp_unit/1,
		 init_local_agent/2,
		 master_agent_loop/3,
		 empty_computation_loop/1,
		 add_node/1,
		 local_agent_loop/4,
		 connect_local_agents/2,
		 stop_cluster/1,
		 stop_nodes/1,
		 pop_node/1,
		 remove_node/2,
		 inform_local_agents/2,
		 get_names/1,
		 get_node_names/1,
		 get_node_pids/1,
		 execute_job/4
		]).

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
	JobQueue = queue:new(),
	master_agent_loop(ComputingUnit, [], JobQueue).
	
init_local_agent(Master, AgentsAlive) ->
	ComputingUnit = init_comp_unit(self()),
	Name = list_to_atom(lists:flatten(io_lib:format("comp_node_~p", [next_node_id(AgentsAlive)]))),
	register(Name, ComputingUnit),
	io:format("with computing unit at ~p ~n", [ComputingUnit]),
	JobQueue = queue:new(),
	local_agent_loop(ComputingUnit, Master, AgentsAlive, JobQueue).

init_comp_unit(AgentPid) -> 
	spawn(middleware, empty_computation_loop, [AgentPid]). 

master_agent_loop(ComputingUnit, AgentsAlive, JobQueue) -> 
	receive
		add -> 
			NewPid = spawn(middleware, init_local_agent, [self(), AgentsAlive]),
			Name = list_to_atom(lists:flatten(io_lib:format("node_~p", [next_node_id(AgentsAlive)]))),
			register(Name, NewPid),
			io:format("New agent on ~p initialized ~n", [NewPid]),
			io:format("Registered under name: ~p~n~n", [Name]),
			% connect all other local agents to the new node
			connect_local_agents(NewPid, AgentsAlive),
			% now we add the new agent to the list of agents alive
			master_agent_loop(ComputingUnit, [NewPid | AgentsAlive], JobQueue);
		pop -> 
			% now we just remove last added node - 
			% but later maybe we will remove the node
			% by some criteria - least loaded etc
			
			% check if there are nodes
			case AgentsAlive of
				[] ->
					io:format("No nodes to remove: cluster contains a single node!~n", []),
					io:format("(To remove master node stop the cluster)~n",[]),
					master_agent_loop(ComputingUnit, AgentsAlive, JobQueue);
				_ ->
					[Node] = lists:sublist(AgentsAlive, 1),
					Node ! stop,
					NewAgentsAlive = lists:delete(Node, AgentsAlive),
					inform_local_agents(Node, NewAgentsAlive),
					{_, Name} = process_info(Node, registered_name),
					unregister(Name),
					io:format("Node '~p' (~p) removed~n", [Name, Node]),
					master_agent_loop(ComputingUnit, NewAgentsAlive, JobQueue)
			end;
		{ remove, Node } ->
			% check if the node is in the list of nodes 
			case lists:member(Node, AgentsAlive) of
				true ->
					Node ! stop,
					NewAgentsAlive = lists:delete(Node, AgentsAlive),
					inform_local_agents(Node, NewAgentsAlive),
					{_, Name} = process_info(Node, registered_name),
					unregister(Name),
					io:format("Node '~p' (~p) removed~n", [Name, Node]),
					master_agent_loop(ComputingUnit, NewAgentsAlive, JobQueue);
				_ ->
					io:format("Node ~p is not found!~n", [Node]),
					master_agent_loop(ComputingUnit, AgentsAlive, JobQueue)
			end;
		{ list_names, Pid } ->
			Pid ! get_names(AgentsAlive),
			master_agent_loop(ComputingUnit, AgentsAlive, JobQueue);
		{ list_pids, Pid } ->
			Pid ! AgentsAlive,
			master_agent_loop(ComputingUnit, AgentsAlive, JobQueue);
		{ n_jobs_request } ->
			io:format("Me (~p) receive request!!!~n", [self()]),
			self() ! { n_jobs, self(), queue:len(JobQueue) },
			master_agent_loop(ComputingUnit, AgentsAlive, JobQueue);
		{ execute, Module, Func, Args} ->
			Pid = elect_least_busy_node([self(), AgentsAlive]),
			Pid ! { execute, Module, Func, Args },
			master_agent_loop(ComputingUnit, AgentsAlive, JobQueue);
		stop -> 
			io:format("Stopping the cluster...~n", []),
			io:format("-----------------------~n", []),
			stop_nodes(AgentsAlive),
			unregister(master_node),
			unregister(master_comp_node),
			io:format("Stopped ~p~n", [master_node])
	end,
	master_agent_loop(ComputingUnit, AgentsAlive, JobQueue).


local_agent_loop(ComputingUnit, Master, AgentsAlive, JobQueue) -> 
	receive
		{ connect, NewPid } ->
			local_agent_loop(ComputingUnit, Master, [NewPid | AgentsAlive], JobQueue);
		{ removed, Node } ->
			io:format("'~p' notified about removal of (~p) ~n", [self(), Node]),
			local_agent_loop(ComputingUnit, Master, lists:delete(Node, AgentsAlive), JobQueue);
		{ n_jobs_request } ->
			io:format("Me (~p) receive request!!!~n", [self()]),
			Master ! { n_jobs, self(), queue:len(JobQueue) },
			local_agent_loop(ComputingUnit, Master, AgentsAlive, JobQueue);
		stop -> 
			{ _, Name } = process_info(ComputingUnit, registered_name),
			unregister(Name),
			ok
	end,
	local_agent_loop(ComputingUnit, Master, AgentsAlive, JobQueue).


empty_computation_loop(AgentPid) ->
	empty_computation_loop(AgentPid).


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

stop_nodes([]) -> ok;
stop_nodes([Agent]) ->
	{ _, Name } = process_info(Agent, registered_name),
	Agent ! stop,
	unregister(Name),
	io:format("Stopped ~w~n", [Name]);
stop_nodes([Agent | T]) ->
	{ _, Name } = process_info(Agent, registered_name),
	Agent ! stop,
	unregister(Name),
	io:format("Stopped ~w~n", [Name]),
	stop_nodes(T).

inform_local_agents(_, []) -> ok;
inform_local_agents(Node, [Agent]) ->
	Agent ! { removed, Node};
inform_local_agents(Node, [Agent | T]) ->
	Agent ! { removed, Node},
	inform_local_agents(Node, T).

get_names([]) -> [];
get_names([ Pid ]) ->
	{ _, Name } = process_info(Pid, registered_name),
	[Name];
get_names([Pid | T]) ->
	{ _, Name } = process_info(Pid, registered_name),
	[Name] ++ get_names(T).

send_election_request([ H ]) ->
	io:format("SEND TOOO ~p~n", [H]),
	H ! { n_jobs_request };

send_election_request([H | T]) ->
	io:format("SEND TOOO ~p~n", [H]),
	H ! { n_jobs_request },
	send_election_request(T).


min_length_queue([{ Pid, N } | T]) ->
	min_length_queue({ Pid, N }, T).

min_length_queue(M, []) -> M;
min_length_queue({ MinPid, MinN }, [{_, N} | T]) when MinN < N ->
	min_length_queue({ MinPid, MinN }, T);
min_length_queue(_, [H | T]) ->
	min_length_queue(H, T).


elect_least_busy_node(AgentsAlive) ->
	send_election_request(AgentsAlive),
	QueuesLenght = lists:map(fun(Pid) -> 
			receive
				{ n_jobs, Pid, N } -> 
					io:format("Process ~p has ~p tasks in the queue~n", [Pid, N]),
					{Pid, N}
				after 1000 -> 
					io:format("Cannot recieve anything!~n"),
					ok
			end
		end,
		AgentsAlive),

	{ Pid, _ } = min_length_queue(QueuesLenght),
	Pid.

% util for generating the tokens to register the processes
next_node_id([]) -> 1;
next_node_id([_]) -> 2;
next_node_id([_ | T]) -> 1 + next_node_id(T).


% Interface functions (IMPLEMENTING MONITOR)
stop_cluster(Pid) ->
	Pid ! stop.

add_node(Pid) -> 
	Pid ! add.

pop_node(Master) ->
	Master ! pop.

get_node_names(Master) -> 
	Master ! {list_names, self()},
	receive
		L -> L
	end.

get_node_pids(Master) ->
	Master ! {list_pids, self()},
	receive
		L -> L
	end.

remove_node(Master, Pid) ->
	Master ! { remove, Pid }.

execute_job(Master, Module, Func, Args) ->
	io:format("Sending request to execute the job to ~p...~n", [Master]),
	Master ! { execute, Module, Func, Args }.