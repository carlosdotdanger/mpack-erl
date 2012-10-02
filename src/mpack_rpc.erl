-module (mpack_rpc).
-include ("mpack.hrl").

-export ([request/3,response/3,notif/2, get_raw_msg/1]).

request(MsgId,Func,Args)->
	mpack:pack([?REQU,MsgId,Func,Args]).

response(MsgId,Err,Results)->
	mpack:pack([?RESP,MsgId,Err,Results]).

notif(Func,Args)->
	mpack:pack([?NOTI,Func,Args]).

%reader is a fun/1 that takes num bytes as arg 
%and returns {ok,Data} or {error,Reason} -
%example: 
% Reader = fun(B) ->
% 	gen_tcp:rcv(MySocket,B,1000)
% end.

%returns raw bytes of message from stream- no decoding,
%useful for passing thru to another service or port
get_raw_msg(Reader)->
	read(Reader).
read(Dat)->
    {ok,Byte} = Dat(1),
read(Byte,Dat).
read(<<?NIL>>,_Dat) -> {ok,<<?NIL>>};
read(<<?FALSE>>,_Dat)-> {ok,<<?FALSE>>};
read(<<?TRUE>>,_Dat) -> {ok,<<?TRUE>>};
read(<<?FLOAT>>,Dat) ->
    {ok,Val} = Dat(4),
    {ok,<<?FLOAT,Val/binary>>};
read(<<?DOUBLE>>,Dat) ->
    {ok,Val} = Dat(8),
    {ok,<<?DOUBLE,Val/binary>>};
read(<<?UINT_8>>,Dat) ->
    {ok,Val} = Dat(1),
    {ok,<<?UINT_8,Val/binary>>};
read(<<?UINT_16>>,Dat) ->
    {ok,Val} = Dat(2),
    {ok,<<?UINT_16,Val/binary>>};
read(<<?UINT_32>>,Dat) ->
    {ok,<<Val/binary>>} = Dat(4),
    {ok,<<?UINT_32,Val>>};
read(<<?UINT_64>>,Dat) ->
    {ok,<<Val/binary>>} = Dat(8),
    {ok,<<?UINT_64,Val>>};
read(<<?INT_8>>,Dat) ->
    {ok,Val} = Dat(1),
    {ok,<<?INT_8,Val/binary>>};
read(<<?INT_16>>,Dat) ->
    {ok,Val} = Dat(2),
    {ok,<<?INT_16,Val/binary>>};
read(<<?INT_32>>,Dat) ->
    {ok,<<Val/binary>>} = Dat(4),
    {ok,<<?INT_32,Val>>};
read(<<?INT_64>>,Dat) ->
    {ok,<<Val/binary>>} = Dat(8),
    {ok,<<?INT_64,Val>>};
read(<<?RAW_16>>,Dat) ->
    {ok,<<Sz:16/big-unsigned-integer>> = Szb} = Dat(2),
    {ok,<<Val:Sz/binary>>} = Dat(Sz),
    {ok,<<?RAW_16,Szb/binary,Val/binary>>};
read(<<?RAW_32>>,Dat) ->
    {ok,<<Sz:32/big-unsigned-integer>> = Szb} = Dat(4),
    {ok,<<Val:Sz/binary>>} = Dat(Sz),
    {ok,<<?RAW_32,Szb/binary,Val/binary>>};
read(<<?ARR_16>>,Dat) ->
    {ok,<<Sz:16/big-unsigned-integer>> = Szb} = Dat(2),
	read_arr(Dat,Sz,<<?ARR_16,Szb/binary>>);
read(<<?ARR_32>>,Dat) ->
    {ok,<<Sz:32/big-unsigned-integer>> = Szb} = Dat(2),
	read_arr(Dat,Sz,<<?ARR_32,Szb/binary>>);
read(<<?MAP_16>>,Dat) ->
    {ok,<<Sz:16/big-unsigned-integer>> = Szb} = Dat(2),
	read_map(Dat,Sz,<<?MAP_16,Szb/binary>>);
read(<<?MAP_32>>,Dat) ->
    {ok,<<Sz:32/big-unsigned-integer>> = Szb} = Dat(2),
	read_map(Dat,Sz,<<?MAP_32,Szb/binary>>);
read(<<?FIX_NEG,_Val:5>> = B, _Dat) -> {ok,B};
read(<<?FIX_POS,_Val:7>> = B,_Dat) -> {ok,B};
read(<<?FIX_MAP,Sz:4>> = B, Dat) -> read_map(Dat,Sz,B);
read(<<?FIX_ARR,Sz:4>> = B, Dat) -> read_arr(Dat,Sz,B);
read(<<?FIX_RAW,Sz:5>> = B, Dat) ->
	case Sz of
		0 -> {ok, B};
		_ ->
			{ok,Val} = Dat(Sz),
			{ok,<<B/binary,Val/binary>>}
	end;
read(Err,_Dat) ->
    {error,{badarg,Err}}.

read_arr(_Dat,0,Acc) -> {ok,Acc};
read_arr(Dat,Sz,Acc)->
	case read(Dat) of
	    {ok,Val} -> read_arr(Dat,Sz-1,<<Acc/binary,Val/binary>>);
		Err -> Err
	end.

read_map(_Dat,0,Acc) -> {ok,Acc};
read_map(Dat,Sz,Acc)->
	case read(Dat) of
	    {ok,Key} ->
			case read(Dat) of
			    {ok,Val,Dat} ->
				read_map(Dat,Sz-1,<<Acc/binary,Key/binary,Val/binary>>);
				Err -> Err
			end;
		Err -> Err
	end.




