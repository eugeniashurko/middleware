-module(example_tasks).
-export ([loop_forever/0,
		  loop_with_timeout/2]).

loop_forever() -> loop_forever().

loop_with_timeout(1, T) ->
	% io:format("Countdown: 1~n", []),
	timer:sleep(T);
loop_with_timeout(N, T) ->
	% io:format("Countdown: ~p~n", [N]),
	timer:sleep(T),
	loop_with_timeout(N-1, T).
	