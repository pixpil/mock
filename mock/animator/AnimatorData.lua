module 'mock'

local tinsert = table.insert

--------------------------------------------------------------------
CLASS: AnimatorData ()

AnimatorData	:MODEL{
		Field 'name'    :string();
		'----';
		Field 'clips'     :array( AnimatorClip ) :no_edit();
		Field 'rootGroup' :type( AnimatorClipGroup ) :no_edit();
	}

function AnimatorData:__init()
	self.name       = 'character'
	self.baseConfig = false
	self.clips      = {}
	self.simpleSkeleton = false
	self.scale   = 1
	self.groups  = {}
	self.rootGroup = AnimatorClipGroup()
	self.rootGroup.name = '__root'
	self.rootGroup.parentPackage = self
end

function AnimatorData:getRootGroup()
	return self.rootGroup
end

function AnimatorData:getSpine()
	return self.spinePath
end

function AnimatorData:setSpine( path )
	self.spinePath = path
end

function AnimatorData:createClipGroup( name, parentGroup )
	parentGroup = parentGroup or self.rootGroup
	local group = AnimatorClipGroup()
	parentGroup:addChildGroup( group )
	group.name = name
	return group
end

function AnimatorData:createClip( name, parentGroup )
	if not self.clips then self.clips = {} end
	local clip = AnimatorClip()
	clip.name = name
	return self:addClip( clip, parentGroup )	
end

function AnimatorData:createClipTree( name, parentGroup )
	if not self.clips then self.clips = {} end
	local clip = AnimatorClipTree()
	clip.name = name
	return self:addClip( clip, parentGroup )	
end

function AnimatorData:addClip( clip, parentGroup )
	parentGroup = parentGroup or self.rootGroup
	--assert self:hasGroup( parentGroup )
	parentGroup:addChildClip( clip )
	return clip
end

function AnimatorData:addClipGroup( group, parentGroup )
	parentGroup = parentGroup or self.rootGroup
	--assert self:hasGroup( parentGroup )
	parentGroup:addChildGroup( group )
	return group
end

function AnimatorData:removeClipGroup( clipGroup )
	local parentGroup = clipGroup.parentGroup
	--remove all clips
	parentGroup:removeChildGroup( clipGroup )
	return true
end

function AnimatorData:removeClip( clip )
	local parentGroup = clipGroup.parentGroup
	parentGroup:removeChildClip( clip )
	return true
end

local function _collectClip( group, list )
	list = list or {}
	for i, clip in ipairs( group.childClips ) do
		tinsert( list, clip )
	end
	for i, childGroup in ipairs( group.childGroups ) do
		_collectClip( childGroup, list )
	end
	return list
end

function AnimatorData:updateClipList()
	self.clips = _collectClip( self.rootGroup )
end

function AnimatorData:getClip( name )
	for i, clip in ipairs( self.clips ) do
		if clip.name == name then return clip end
	end
	return nil
end

function AnimatorData:getClipNames()
	local result = {}
	for _, clip in ipairs( self.clips ) do
		local name = clip.name
		tinsert( result, { name, name } )
	end
	return result
end


function AnimatorData:sortEvents() --pre-serialization
	for i, clip in ipairs( self.clips ) do
		for _, track in ipairs( clip.tracks ) do
			track:sortEvents()
		end
	end
end

function AnimatorData:_postLoad() --post-serialization
	if not self.rootGroup then
		self.rootGroup = AnimatorClipGroup()
		self.rootGroup.name = '__root'
	end
	local rootGroup = self.rootGroup
	rootGroup.parentPackage = self
	local clips = self.clips
	for i = 1, #clips do
		local clip = clips[i] --backward compatibilty
		if not clip.parentGroup then
			rootGroup:addChildClip( clip )
		end
	end
	self:updateClipList()
	rootGroup:_postLoad()
	
end

function AnimatorData:prebuildAll()
	return self.rootGroup:prebuildAll()
end


--------------------------------------------------------------------
--------------------------------------------------------------------
function loadAnimatorDataFromRaw( data )
	_Stopwatch.start( 'animator_data_load_deserialization' )
	local animatorData = mock.deserialize( nil, data )
	_Stopwatch.stopAndLog( 'animator_data_load_deserialization' )
	animatorData:_postLoad()
	return animatorData
end

function loadAnimatorDataFromString( strData )
	local t = MOAIJsonParser.decode( strData )
	return loadAnimatorDataFromRaw( t )
end

function loadAnimatorData( node )
	local data   = mock.loadAssetDataTable( node:getObjectFile('data') )
	node:disableGC()
	return loadAnimatorDataFromRaw( data )
end

mock.registerAssetLoader( 'animator_data', loadAnimatorData )
