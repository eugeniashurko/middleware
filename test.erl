-module(test).
-export([main/0]).

main() ->
	ClusterPid = spawn(middleware, start, []),
	io:format("Successfully started the cluster on ~p ~n~n", [ClusterPid]),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	io:format("Nodes: ~w ~n", [middleware:get_node_names(ClusterPid)]),
	io:format("Pids: ~w ~n~n", [middleware:get_node_pids(ClusterPid)]),
	middleware:pop_node(ClusterPid),
	io:format("Nodes: ~w ~n", [middleware:get_node_names(ClusterPid)]),
	Pids = middleware:get_node_pids(ClusterPid),
	io:format("Pids: ~w ~n~n", [Pids]),
	middleware:remove_node(ClusterPid, lists:last(Pids)),
	io:format("Nodes: ~w ~n", [middleware:get_node_names(ClusterPid)]),
	io:format("Pids: ~w ~n~n", [middleware:get_node_pids(ClusterPid)]),
	middleware:stop_cluster(ClusterPid).
