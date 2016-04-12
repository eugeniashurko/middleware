-module(utils).
-export([min_length_queue/1,
 		 multi_delete/2,
 		 inform_local_agents/2,
		 multi_inform_local_agents/2,
		 multi_keyreplace/2]).


min_length_queue([ M ]) ->
	M;
min_length_queue([{ Node, N } | T]) ->
	min_length_queue({ Node, N }, T).

min_length_queue(M, []) -> M;
min_length_queue({ MinNode, MinN }, [{_, N} | T]) when MinN < N ->
	min_length_queue({ MinNode, MinN }, T);
min_length_queue(_, [H | T]) ->
	min_length_queue(H, T).


multi_delete([ ], List) -> List; 
multi_delete([ Element ], List) ->
	lists:delete(Element, List);
multi_delete([ Element | T ], List) ->
	NewList = lists:delete(Element, List),
	multi_delete(T, NewList).


inform_local_agents(_, []) -> ok;
inform_local_agents(NodeToRemove, [ Node ]) ->
	{ agent, Node } ! { removed, NodeToRemove },
	ok;
inform_local_agents(NodeToRemove, [Node | T]) ->
	{ agent, Node } ! { removed, NodeToRemove },
	inform_local_agents(NodeToRemove, T).


multi_inform_local_agents([], _) -> ok;
multi_inform_local_agents([ NodeToRemove ], Nodes) ->
	inform_local_agents(NodeToRemove, Nodes),
	ok;
multi_inform_local_agents([ NodeToRemove | T ], Nodes) ->
	inform_local_agents(NodeToRemove, Nodes),
	multi_inform_local_agents(T, Nodes).

multi_keyreplace([ ], NodesHistory) ->
	NodesHistory;
multi_keyreplace([ DeadNode ], NodesHistory) -> 
	lists:keyreplace(DeadNode, 1, NodesHistory, {DeadNode, dead});
multi_keyreplace([ DeadNode | T ], NodesHistory) ->
	NewHistory = lists:keyreplace(DeadNode, 1, NodesHistory, {DeadNode, dead}),
	multi_keyreplace(T, NewHistory).
