-compile(utils).
-compile(agents).
-compile(monitor).

% open_file(FileName, Mode) ->
%     {ok, Device} = file:open(FileName, [Mode, binary]),
%     Device.

% close_file(Device) ->
%     ok = file:close(Device).

% read_lines(Device, L) ->
%     case io:get_line(Device, L) of
%         eof ->
%             lists:reverse(L);
%         String ->
%             read_lines(Device, [String | L])
%     end.

readlines(FileName) ->
    {ok, Data} = file:read_file(FileName),
    binary:split(Data, [<<"\n">>], [global]).

main([]) ->
	io:format("Error: No config file specified!~n", []);
main([InputFileName]) ->
	% read list of
	% Device = open_file(InputFileName, read),
    Data = readlines(InputFileName),
	Nodes = lists:map(
		fun(Name) -> list_to_atom(binary_to_list(Name)) end,
		Data),

	register(monitor, self()),
	MasterNode = lists:sublist(Nodes,1,1),
	SlaveNodes = lists:sublist(Nodes,2, length(Nodes)),

	monitor:start_cluster(MasterNode, SlaveNodes),

	io:format("Nodes: ~w ~n", [monitor:get_nodes(MasterNode)]),
	monitor:show_nodes_history(MasterNode).