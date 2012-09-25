-module (mpack_rpc).
-include ("mpack.hrl").

-export ([request/3,response/3,notif/2]).

request(Id,Func,Args)->
	mpack:pack([?REQU,Id,Func,Args]).

response(Id,Err,Results)->
	mpack:pack([?RESP,Id,Err,Results]).

notif(Func,Args)->
	mpack:pack([?NOTI,Func,Args]).
