-module(monitor_test).
-export([main/0,
		 flood_cluster/3]).


flood_cluster(MasterNode, Job, 1) ->
	monitor:execute_job(MasterNode, Job);
flood_cluster(MasterNode, Job, N) ->
	monitor:execute_job(MasterNode, Job),
	flood_cluster(MasterNode, Job, N - 1).

main() ->
	register(monitor, self()),
	MasterNode = 'node1_1@johnpaul-ENS-Workstation',
	Nodes = ['node2_1@johnpaul-ENS-Workstation',
			 'node3_1@johnpaul-ENS-Workstation',
			 'node4_1@johnpaul-ENS-Workstation'],
	monitor:start_cluster(MasterNode, Nodes),
	timer:sleep(1000),
	io:format("Nodes: ~w ~n", [monitor:get_nodes(MasterNode)]),
	timer:sleep(1000),
	% monitor:pop_node(MasterNode),
	% io:format("Nodes: ~w ~n", [monitor:get_nodes(MasterNode)]),
	% timer:sleep(1000),
	% monitor:remove_node(MasterNode, 'node3_1@johnpaul-ENS-Workstation'),
	% io:format("Nodes: ~w ~n", [monitor:get_nodes(MasterNode)]),
	flood_cluster(MasterNode, {example_tasks, loop_with_timeout, [4, 10000]}, 100),
	timer:sleep(1000),
	monitor:remove_node(MasterNode, 'node3_1@johnpaul-ENS-Workstation'),
	timer:sleep(10000),
	monitor:show_nodes_history(MasterNode),
	monitor:stop_cluster(MasterNode).
