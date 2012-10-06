-module (mpack_stream).
-include ("mpack.hrl").
-export ([dcode/1]).

%Dat is a fun/1 that takes num bytes as arg 
%and returns {ok,Data} or {error,Reason} -
%example: 
% Dat = fun(B) ->
% 	gen_tcp:rcv(MySocket,B,1000)
% end.

dcode(Dat)->
    {ok,Byte} = Dat(1),
dcode(Byte,Dat).
dcode(<<?NIL>>,_Dat) -> {ok,nil};
dcode(<<?FALSE>>,_Dat)-> {ok,false};
dcode(<<?TRUE>>,_Dat) -> {ok,true};
dcode(<<?FLOAT>>,Dat) ->
    {ok,<<Val:32/float>>} = Dat(4),
    {ok,Val};
dcode(<<?DOUBLE>>,Dat) ->
    {ok,<<Val:64/float>>} = Dat(8),
    {ok,Val};
dcode(<<?UINT_8>>,Dat) ->
    {ok,<<Val:8/big-unsigned-integer>>} = Dat(1),
    {ok,Val};
dcode(<<?UINT_16>>,Dat) ->
    {ok,<<Val:16/big-unsigned-integer>>} = Dat(2),
    {ok,Val};
dcode(<<?UINT_32:8>>,Dat) ->
    {ok,<<Val:32/big-unsigned-integer>>} = Dat(4),
    {ok,Val};
dcode(<<?UINT_64>>,Dat) ->
    {ok,<<Val:64/big-unsigned-integer>>} = Dat(8),
    {ok,Val};
dcode(<<?INT_8>>,Dat) ->
    {ok,<<Val:8/big-signed-integer>>} = Dat(1),
    {ok,Val};
dcode(<<?INT_16>>,Dat) ->
    {ok,<<Val:16/big-signed-integer>>} = Dat(2),
    {ok,Val};
dcode(<<?INT_32>>,Dat) ->
    {ok,<<Val:32/big-signed-integer>>} = Dat(4),
    {ok,Val};
dcode(<<?INT_64>>,Dat) ->
    {ok,<<Val:64/big-signed-integer>>} = Dat(8),
    {ok,Val};
dcode(<<?RAW_16>>,Dat) ->
    {ok,<<Sz:16/big-unsigned-integer>>} = Dat(2),
    {ok,<<Val:Sz/binary>>} = Dat(Sz),
    {ok,Val};
dcode(<<?RAW_32>>,Dat) ->
    {ok,<<Sz:32/big-unsigned-integer>>} = Dat(4),
    {ok,<<Val:Sz/binary>>} = Dat(Sz),
    {ok,Val};
dcode(<<?ARR_16>>,Dat) ->
    {ok,<<Sz:16/big-unsigned-integer>>} = Dat(2),
dcode_arr(Dat,Sz);
dcode(<<?ARR_32>>,Dat) ->
    {ok,<<Sz:32/big-unsigned-integer>>} = Dat(4),
	dcode_arr(Dat,Sz);
dcode(<<?MAP_16>>,Dat) ->
	{ok,<<Sz:16/big-unsigned-integer>>} = Dat(2),
	dcode_map(Dat,Sz);
dcode(<<?MAP_32>>,Dat) ->
	{ok,<<Sz:32/big-unsigned-integer>>} = Dat(4),
	dcode_map(Dat,Sz);
dcode(<<?FIX_NEG,Val:5/unsigned-integer>>,_Dat) -> {ok,Val + ?MIN_5};
dcode(<<?FIX_POS,Val:7>>,_Dat) -> {ok,Val};
dcode(<<?FIX_MAP,Sz:4>>, Dat) -> dcode_map(Dat,Sz);
dcode(<<?FIX_ARR,Sz:4>>, Dat) ->
	dcode_arr(Dat,Sz);
dcode(<<?FIX_RAW,Sz:5>>, Dat) ->
	case Sz of
		0 -> {ok,<<>>};
		X ->
			{ok,<<Val:X/binary>>} = Dat(Sz),
			{ok,Val}
	end;
dcode(Err,_Dat) ->
    {error,{badarg,Err}}.

dcode_arr(Dat,Sz) ->
dcode_arr(Dat,Sz,queue:new()).
dcode_arr(_Dat,0,Acc) -> {ok,queue:to_list(Acc)};
dcode_arr(Dat,Sz,Acc)->
	case dcode(Dat) of
	    {ok,Val} -> dcode_arr(Dat,Sz-1,queue:in(Val,Acc));
		Err -> Err
	end.

dcode_map(Dat,Sz) -> dcode_map(Dat,Sz,queue:new()).
dcode_map(_Dat,0,Acc) -> {ok,queue:to_list(Acc)};
dcode_map(Dat,Sz,Acc)->
	case dcode(Dat) of
	    {ok,Key} ->
			case dcode(Dat) of
			    {ok,Val,Dat} ->
				dcode_map(Dat,Sz-1,queue:in({Key,Val},Acc));
				Err -> Err
			end;
		Err -> Err
	end.
