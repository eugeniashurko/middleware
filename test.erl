-module(test).
-export([main/0,
		 flood_cluster/3]).

flood_cluster(Pid, Job, 1) ->
	middleware:execute_job(Pid, Job);
flood_cluster(Pid, Job, N) ->
	middleware:execute_job(Pid, Job),
	flood_cluster(Pid, Job, N - 1).
	

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
	flood_cluster(ClusterPid, {example_tasks, loop_with_timeout, [4, 10000]}, 100).



	% erl -sname node1
	% erl -sname node2
	% ...
	% for example node 2 does
	% register(alala, Pid)
	% then guy can send message:
	% {alala, node1@host} ! message
	% 