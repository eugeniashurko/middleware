-module(test).
-export([main/0]).

main() ->
	ClusterPid = spawn(middleware, start, []),
	io:format("Successfully started the cluster on ~p ~n~n", [ClusterPid]),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	middleware:add_node(ClusterPid),
	middleware:stop_cluster(ClusterPid).
