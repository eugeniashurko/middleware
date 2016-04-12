-module(agents).
-export([start/0,
		 init_comp_unit/1,
		 init_local_agent/2,
		 master_agent_loop/4,
		 computation_loop/1,
		 local_agent_loop/4,
		 connect_local_agents/2,
		 stop_nodes/1,
		 repartition_queue/4,
		 elect_least_busy_node/2]).

% At the beginning we have master agent 
start() ->
	% Master agent starts here
	MyPid = self(),
	register(agent, MyPid),
	io:format("Here is our entry point initialized on ~s (process '~p')~n", [node(), agent]),
	% Here it initializes the corresponding computing unit
	ComputingUnit = init_comp_unit(MyPid),
	register(comp_unit, ComputingUnit),
	io:format("Corresponding computing unit ~p~n", [ComputingUnit]),
	master_agent_loop(ComputingUnit, [], queue:new(), []).

init_comp_unit(AgentPid) -> 
	spawn(agents, computation_loop, [AgentPid]). 

init_local_agent(MasterNode, NodesAlive) ->
	% here check dead nodes
	register(agent, self()),
	ComputingUnit = init_comp_unit(self()),
	register(comp_unit, ComputingUnit),
	io:format("New agent on ~p (process ~p) initialized ~n", [node(), self()]),
	io:format("with computing unit at process ~p ~n", [ComputingUnit]),
	local_agent_loop(ComputingUnit, MasterNode, NodesAlive, queue:new()).

master_agent_loop(ComputingUnit, PrevNodesAlive, JobQueue, PrevNodesHistory) ->
	{ DeadNodes, NodesAlive } = check_alive(PrevNodesAlive),
	case length(DeadNodes) > 0 of
		true -> 
			utils:multi_inform_local_agents(DeadNodes, NodesAlive),
			NodesHistory = utils:multi_keyreplace(DeadNodes, PrevNodesHistory);
		false -> 
			NodesHistory = PrevNodesHistory
	end,
	receive
		{ add, Node } ->
			case net_adm:ping(Node) of
				pong ->
					spawn(Node, agents, init_local_agent, [node(), NodesAlive]),
					% connect all other local agents to the new node
					connect_local_agents(Node, NodesAlive),
					% now we add the new agent to the list of agents alive
					master_agent_loop(ComputingUnit, [Node | NodesAlive], JobQueue, [{Node, alive} | NodesHistory]);
				pang -> 
					io:format("Node ~s is not reachable", [Node]),
					master_agent_loop(ComputingUnit, NodesAlive, JobQueue, NodesHistory)
			end;
		{ list_nodes, MonitorNode } ->
			{ monitor, MonitorNode } ! NodesAlive,
			master_agent_loop(ComputingUnit, NodesAlive, JobQueue, NodesHistory);
		{ get_nodes_history, MonitorNode } ->
			{ monitor, MonitorNode } ! NodesHistory; 
		pop -> 
			% now we just remove last added node - 
			% but later maybe we will remove the node
			% by some criteria - least loaded etc
			
			% check if there are nodes
			case NodesAlive of
				[] ->
					io:format("No nodes to remove: cluster contains a single node!~n", []),
					io:format("(To remove master node stop the cluster)~n",[]),
					master_agent_loop(ComputingUnit, NodesAlive, JobQueue, NodesHistory);
				_ ->
					[Node] = lists:sublist(NodesAlive, 1),
					{ agent, Node } ! get_queue,
					receive
						{queue, Queue} -> 
							NewJobQueue = repartition_queue(
								ComputingUnit, lists:delete(Node, NodesAlive), JobQueue, Queue
							)
						after 1000 ->
							NewJobQueue = JobQueue,
							io:format("Node queue was lost~n", [])
					end,
					{ agent, Node } ! stop,
					NewNodesAlive = lists:delete(Node, NodesAlive),
					utils:inform_local_agents(Node, NewNodesAlive),
					io:format("Node ~p removed~n", [Node]),
					master_agent_loop(ComputingUnit,
									  NewNodesAlive,
									  NewJobQueue,
									  lists:keyreplace(Node, 0, NodesHistory, {Node, removed}))
			end;
		{ remove, Node } ->
			% check if the node is in the list of nodes 
			case lists:member(Node, NodesAlive) of
				true ->
					{ agent, Node } ! get_queue,
					receive
						{queue, Queue} -> 
							NewJobQueue = repartition_queue(
								ComputingUnit, lists:delete(Node, NodesAlive), JobQueue, Queue
							)
						after 1000 ->
							NewJobQueue = JobQueue,
							io:format("Node queue was lost~n", [])
					end,
					{ agent, Node} ! stop,
					NewNodesAlive = lists:delete(Node, NodesAlive),
					utils:inform_local_agents(Node, NewNodesAlive),
					io:format("Node ~p removed~n", [Node]),
					master_agent_loop(ComputingUnit,
									  NewNodesAlive,
									  NewJobQueue,
									  lists:keyreplace(Node, 1, NodesHistory, {Node, removed}));
				_ ->
					io:format("Node ~p is not found!~n", [Node]),
					master_agent_loop(ComputingUnit, NodesAlive, JobQueue, NodesHistory)
			end;
		{ find_node_to_execute, Job} ->
			{NewNodesAlive, NewJobQueue} = sent_job_to_execution(ComputingUnit, NodesAlive, JobQueue, Job),
			master_agent_loop(ComputingUnit, NewNodesAlive, NewJobQueue, NodesHistory);
		{ finished, Result } ->
			io:format("Computation Result: ~p~n", [Result]),
			NewQueue = queue:drop(JobQueue),
			case queue:is_empty(NewQueue) of
				false -> 
					NewJob = queue:get(NewQueue),
					ComputingUnit ! { new_job, NewJob };
				true -> ok
			end,
			master_agent_loop(ComputingUnit, NodesAlive, NewQueue, NodesHistory);
		{ report_dead, DeadNodes } ->
			io:format("Nodes ~w are dead!~n", [DeadNodes]),
			NewNodesAlive = utils:multi_delete(DeadNodes, NodesAlive),
			utils:multi_inform_local_agents(DeadNodes, NewNodesAlive),
			NewNodesHistory = utils:multi_keyreplace(DeadNodes, NodesHistory),
			master_agent_loop(ComputingUnit, NewNodesAlive, JobQueue, NewNodesHistory);
		stop -> 
			io:format("Stopping the cluster...~n", []),
			io:format("-----------------------~n", []),
			stop_nodes(NodesAlive),
			unregister(agent),
			exit(ComputingUnit, "Kill the computing unit"),
			unregister(comp_unit),
			io:format("Stopped Master Node~n", [])
	end,
	master_agent_loop(ComputingUnit, NodesAlive, JobQueue, NodesHistory).


computation_loop(AgentPid) ->
	receive
		{ new_job, {Module, Func, Args} } ->
			Result = erlang:apply(Module, Func, Args),
			AgentPid ! { finished, Result },
			computation_loop(AgentPid)
	end,
	computation_loop(AgentPid).


local_agent_loop(ComputingUnit, MasterNode, PrevNodesAlive, JobQueue) -> 
	% check wheather master node is alive
	case net_adm:ping(MasterNode) of
		pong -> 
			ok;
		pang ->
			io:format("CANNOT CONNECT TO MASTER NODE: ~p!~n", [MasterNode]),
			local_agent_loop(ComputingUnit, MasterNode, PrevNodesAlive, JobQueue)
	end,
	% check wheather other nodes are alive
	{ DeadNodes, NodesAlive } = check_alive(PrevNodesAlive),
	case length(DeadNodes) > 0 of
		true -> { agent, MasterNode } ! { report_dead, DeadNodes };
		false -> ok
	end,
	receive
		{ connect, NewNode } ->
			net_adm:ping(NewNode),
			local_agent_loop(ComputingUnit, MasterNode, [NewNode | NodesAlive], JobQueue);
		{ removed, Node } ->
			io:format("~p notified about removal of (~p) ~n", [node(), Node]),
			local_agent_loop(ComputingUnit, MasterNode, lists:delete(Node, NodesAlive), JobQueue);
		{ n_jobs_request } ->
			{ agent, MasterNode} ! { n_jobs, node(), queue:len(JobQueue) },
			local_agent_loop(ComputingUnit, MasterNode, NodesAlive, JobQueue);
		{ execute_job, Job} ->
			case queue:is_empty(JobQueue) of
				true -> 
					ComputingUnit ! { new_job, Job };
				false -> ok				
			end,
			NewQueue = queue:in(Job, JobQueue),
			local_agent_loop(
						ComputingUnit,
						MasterNode,
						NodesAlive,
						NewQueue);
		{ finished, Result } ->
			io:format("Computation Result: ~p~n", [Result]),
			NewQueue = queue:drop(JobQueue),
			case queue:is_empty(NewQueue) of
				false -> 
					NewJob = queue:get(NewQueue),
					ComputingUnit ! { new_job, NewJob };
				true -> ok
			end,
			local_agent_loop(
				ComputingUnit,
				MasterNode,
				NodesAlive,
				NewQueue);
		get_queue -> 
			{ agent, MasterNode } ! { queue, JobQueue },
			local_agent_loop(ComputingUnit, MasterNode, NodesAlive, JobQueue);
		stop -> 
			unregister(comp_unit),
			unregister(agent),
			exit(ComputingUnit, "Kill the computing unit"),
			ok
	end,
	local_agent_loop(ComputingUnit, MasterNode, NodesAlive, JobQueue).


connect_local_agents(_, []) -> 
	ok;
connect_local_agents(NewNode, [ Node ]) ->
	{ agent, Node } ! {connect, NewNode},
	io:format("connected to  ~p~n~n", [Node]),
	ok;
connect_local_agents(NewNode, [ Node | T ]) ->
	{ agent, Node } ! {connect, NewNode},
	io:format("connected to  ~p~n", [Node]),
	connect_local_agents(NewNode, T).


stop_nodes([]) -> ok;
stop_nodes([Node]) ->
	{ agent, Node } ! stop,
	io:format("Stopped ~p~n", [Node]);
stop_nodes([Node | T]) ->
	{ agent, Node } ! stop,
	io:format("Stopped ~p~n", [Node]),
	stop_nodes(T).

check_alive(Nodes) ->
	TempNodes = lists:map(fun(Node) -> 
			case net_adm:ping(Node) of
				pong -> 
					{Node, alive};
				pang -> 
					io:format("Node ~p is dead!~n", [Node]),
					{Node, dead}
			end
		end,
		Nodes),
	DeadNodesFiltered = lists:filter(
		fun(NodeName) ->
			case NodeName of
				{ _, dead } -> true;
				{ _, alive } -> false
			end
		end, 
		TempNodes),
	NodesAliveFiltered = lists:filter(
		fun(NodeName) ->
			case NodeName of
				{ _ , dead } -> false;
				{ _ , alive } -> true
			end
		end, 
		TempNodes),

	DeadNodes = lists:map(fun({ Node, dead }) -> Node end, DeadNodesFiltered),
	NodesAlive = lists:map(fun({ Node, alive }) -> Node end, NodesAliveFiltered),
	{ DeadNodes, NodesAlive }.

elect_least_busy_node(MasterQueue, PrevNodesAlive) ->
	{ DeadNodes, NodesAlive } = check_alive(PrevNodesAlive),
	case length(DeadNodes) > 0 of
		true -> utils:multi_inform_local_agents(DeadNodes, NodesAlive);
		false -> ok
	end,
	QueuesLenght = lists:map(fun(Node) -> 
			{ agent, Node } ! { n_jobs_request },
			receive
				{ n_jobs, Node, N } -> 
					{Node, N}
				after 1000 -> 
					io:format("Cannot recieve anything!~n")
			end
		end,
		NodesAlive),
	% We append master node Pid at the end of the list
	% so that if both master and other node will have the same
	% min number of jobs in queue, the job will be sent to other
	% processor, cause we don't want to bother master node to much
	% cause he is already rather busy
	QueuesLenghtWithMaster = lists:append([[{ node(), MasterQueue }], QueuesLenght]),
	% io:format("Queue lengths for nodes: ~w~n", [QueuesLenghtWithMaster]),
	{ SelectedNode, _ } = utils:min_length_queue(QueuesLenghtWithMaster),
	{ SelectedNode, NodesAlive }.


sent_job_to_execution(ComputingUnit, NodesAlive, JobQueue, Job) ->
	N = queue:len(JobQueue),
	{Node, NewNodesAlive} = elect_least_busy_node(N, NodesAlive),
	case Node == node() of
		true ->
			case queue:is_empty(JobQueue) of
				true -> 
					ComputingUnit ! { new_job, Job };
				false ->
					ok
			end,
			NewQueue = queue:in(Job, JobQueue),
			{NewNodesAlive, NewQueue};
		false -> 
			{ agent, Node } ! { execute_job, Job },
			{NewNodesAlive, JobQueue}
	end.

repartition_queue(ComputingUnit, NodesAlive, JobQueue, Queue) ->
	case queue:is_empty(Queue) of
		true -> 
			JobQueue;
		_ ->
			Job = queue:get(Queue),
			NewQueue = queue:drop(Queue),
			{NewNodesAlive, NewMasterQueue} = sent_job_to_execution(ComputingUnit, NodesAlive, JobQueue, Job),
			repartition_queue(ComputingUnit, NewNodesAlive, NewMasterQueue, NewQueue)
	end.



