-module(monitor).
-export([start_cluster/1,
		 start_cluster/2,
		 add_node/2,
		 add_nodes/2,
		 stop_cluster/1, 
		 get_nodes/1,
		 pop_node/1,
		 remove_node/2,
		 execute_job/2]).

% Interface functions (IMPLEMENTING MONITOR)

start_cluster(MasterNode) ->
	case net_adm:ping(MasterNode) of
		pong ->
			spawn(MasterNode, agents, start, []);
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.

start_cluster(MasterNode, Nodes) ->
	case net_adm:ping(MasterNode) of
		pong ->
			spawn(MasterNode, agents, start, []),
			add_nodes(MasterNode, Nodes);
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.


add_node(MasterNode, Node) -> 
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode} ! { add, Node },
			ok;
		pang ->
			io:format("Node ~p is not reachable", [MasterNode]),
			not_ok
	end.

add_nodes(_, []) -> ok;
add_nodes(MasterNode, [ Node ]) ->
	add_node(MasterNode, Node),
	ok;

add_nodes(MasterNode, [Node | Tail]) ->
	case add_node(MasterNode, Node) of
		ok -> add_nodes(MasterNode, Tail);
		_ -> 
			add_node(MasterNode, Node),
			add_nodes(MasterNode, Tail)
	end.

stop_cluster(MasterNode) ->
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode } ! stop;
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.


get_nodes(MasterNode) -> 
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode } ! { list_nodes, node() };
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end,
	receive
		L -> lists:append([L, [MasterNode]])
	after 1000 -> 
		io:format("Didn't get any list~n", [])
	end.

pop_node(MasterNode) ->
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode } ! pop;
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.

remove_node(MasterNode, Node) ->
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode} ! { remove, Node };
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.

execute_job(MasterNode, Job) ->
	case net_adm:ping(MasterNode) of
		pong ->
			{ agent, MasterNode} ! { find_node_to_execute, Job };
		pang ->
			io:format("Node ~p is not reachable", [MasterNode])
	end.
