module 'mock'

CLASS: DebugAudioView ( mock.DebugUIModule )
:register( 'audio' )

--------------------------------------------------------------------
function DebugAudioView:__init()
	self.trackedValues = {}
end

function DebugAudioView:getTitle()
	return 'Audio'
end

function DebugAudioView:onDebugGUI( gui, scn )
	self:subVolume( gui, scn )
	self:subGlobalSound( gui, scn )
	self:subLog( gui, scn )
end

function DebugAudioView:addVolumeWidget( gui, scn, category )
	local mgr = AudioManager.get()
	gui.PushID( 'volume_widget/' .. category)

	gui.Text( category )
	gui.SameLine()
	local changed, audible = gui.Checkbox( '##audible', not mgr:isCategoryMuted( category ) )
	if changed then	mgr:setCategoryMuted( category, not audible ) end

	gui.SameLine()
	local vol = mgr:getCategoryVolume( category )
	if audible then
		gui.PushStyleColor( MOAIImGui.Col_FrameBg, 0.1, vol*0.2, vol*0.4 , 1 )
	else
		gui.PushStyleColor( MOAIImGui.Col_FrameBg, 0.2,0,0,1 )
	end
	local changed, value = gui.SliderInt( "##volume", vol * 100, 0, 100, '%.0f%%')
	if changed then mgr:setCategoryVolume( category, value/100 ) end
	gui.PopStyleColor(1)

	gui.PopID()
end

function DebugAudioView:subVolume( gui, scn )
	if gui.CollapsingHeader( 'Volume' ) then
		self:addVolumeWidget( gui, scn, 'master' )
	end
end

function DebugAudioView:subGlobalSound( gui, scn )
	if gui.CollapsingHeader( 'Global Sound' ) then
		gui.BeginChild( 'GlobalSound', 0, 150 )
		local player = mock.getGlobalSoundPlayer()
		local list = player:getSessionList()
		for i, session in ipairs( list ) do
			local name = session.name
			gui.PushID( 'session_'..name )
			local event = session:getCurrentEvent()
			local playing = session:isPlaying()
			gui.Text( name )
			gui.SameLine( 120 )
			if playing then
				gui.PushStyleColor( MOAIImGui.Col_Button, hexcolor('#489317') )
			else
				gui.PushStyleColor( MOAIImGui.Col_Button, hexcolor('#392020') )
			end
			if gui.Button( ( event and basename(event) ) or '<no sound>' ) then
				--pop asset search
			end
			gui.SameLine( 240 )
			local instanceVolume = session:getEventInstanceVolume()
			local volume = session:getVolume()
			gui.Text( string.format( '%d/%d', instanceVolume * 100, volume*100 ) )
			gui.PopStyleColor(1)
			gui.PopID()
		end
		gui.EndChild()
	end
end

function DebugAudioView:subLog( gui, scn )
	if gui.CollapsingHeader( 'Event Log', MOAIImGui.TreeNodeFlags_DefaultOpen ) then
		gui.BeginChild( 'EventLogs' )
		local logs = AudioManager.get():getLogs()
		local size = logs:getSize()
		for i = 1, size do
			local entry = logs:get( i )
			local eventPath, info = unpack( entry )
			if info.id then
				gui.PushID( info.id )
				if gui.Button( '>>' ) then
					AudioManager.get():sendEditCommand( 'locate', { id = info.id } )
				end
				gui.SameLine()
				gui.Text( tostring(eventPath) )
				gui.PopID()
			end
		end
		gui.EndChild()
	end
end

