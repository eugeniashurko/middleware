-module(test).
-export([main/0]).

main() ->
	ClusterPid = spawn(middleware, start, []),
	io:format("Successfully started the cluster on ~p ~n~n", [ClusterPid]).
	% TODO
	% add_node(ClusterPid)
	% NodeId = ...
	% remove_node(ClusterPid, NodeId)
