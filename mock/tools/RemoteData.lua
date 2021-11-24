--[[
* MOCK framework for Moai

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

CLASS: RemoteData ()
	

registerGlobalSignals{
	'remotedata.ready',
	'remotedata.fail',
}

local _remoteDataCallback=function(task,code)

	if code~=200 then
		return task.owner:_onFail(code)
	else		
		return task.owner:_onReady(task:getString())
	end

end

function RemoteData.getSync( url, callback )
	local rd = RemoteData( url, 'get', nil, callback )
	rd:setBlocking( true )
	return rd:_startFetch()
end

function RemoteData.get( url, callback )
	local rd = RemoteData( url, 'get', nil, callback )
	return rd:_startFetch()
end

function RemoteData.post( url, postData, callback )
	local rd = RemoteData( url, 'get', postData, callback )
	return rd:_startFetch()
end

function RemoteData:__init( url, method, postData, callback )
	self.url = url
	self.method = method or 'get'
	self.postData = postData
	self.callback = callback
	self.blocking = false
	self.verbose = false
end

function RemoteData:setBlocking( blocking )
	self.blocking = blocking ~= false
end

function RemoteData:setVerbose( verbose )
	self.verbose = verbose ~= false
end

function RemoteData:_startFetch()
	local task = MOAIHttpTask.new()

	local url = self.url
	local method = self.method
	local agent = nil
	local verbose = self.verbose
	local blocking = self.blocking

	task.owner = self
	task:setCallback( _remoteDataCallback )

	if method=='post' then
		local data = self.postData
		task:httpPost( url, data, agent, verbose, blocking )
	else
		task:httpGet( url, agent, verbose, blocking )
	end
	return self
end

function RemoteData:isDone()
	return self.done
end

function RemoteData:refetch()
	self.done = false
	self.recvData  = false
	self.errorCode = false
	self:_startFetch()
end

function RemoteData:toString()
	return self.recvData
end

function RemoteData:toDataBuffer()
	local buf = MOAIDataBuffer.new()
	buf:setString(self.recvData)
	return buf
end

function RemoteData:toImage()
	local buf = self:toDataBuffer()	
	local img = MOAIImage.new()
	img:load(buf)
	return img
end

function RemoteData:_onReady(data)
	self.done = true
	self.recvData = data
	
	local callback = self.callback
	if callback then
		callback( self, true, data )
	end
	
	emitSignal( 'remotedata.ready', self, data )
end

function RemoteData:_onFail( code )
	self.done = true
	self.errorCode = code

	local callback = self.callback
	if callback then
		callback( self, false, code )
	end

	emitSignal('remotedata.fail',self,code)
end


