-module(utils).
-export([start/0,
		 local_agent_loop/0]).

start() ->
	Pid = spawn(utils, local_agent_loop, []),
	register(other_node, Pid),
	% io:format(),
	net_kernel:connect_node(Pid).

local_agent_loop() -> 
	local_agent_loop().
