module 'mock'

local DEFAULT_TOUCH_PADDING = 10
local insert, remove = table.insert, table.remove

--------------------------------------------------------------------
local function widgetZSortFunc( w1, w2 )
	if w1 == w2 then return false end
	local z1 = w1.zorder
	local z2 = w2.zorder
	if z1 == z2 then
		return w1._priority < w2._priority
	else
		return z1 < z2
	end
end

local function _updateRectCallback( node )
	return node.__src:onRectChange()
end

local function makeRectNode( src )
	local node = MOAIScriptNode.new()
	node.__src = src
	node:reserveAttrs( 4 )
	node:setCallback( _updateRectCallback )
	return node
end

--------------------------------------------------------------------
--------------------------------------------------------------------
CLASS: UIWidgetBase ( Entity )
	:MODEL{
		Field 'style' :asset_pre( 'ui_style' ) :getset( 'LocalStyleSheet' );
		Field 'stringTable' :asset( 'data_sheet' ) :onset( 'updateStringTable' );
	}
	:META{
		category = 'UI'
	}

--no difference for now.
local newUIProp = MOCKUIProp.new
function UIWidgetBase:_createEntityProp()
	return newUIProp()
end

function UIWidgetBase:__init()
	self.FLAG_UI_WIDGET = true
	self.childWidgets   = {}
	self.localStyleSheetPath = false
	self.localStyleSheet = false
	self.inheritedStyleSheet = false
	self.inputEnabled = true
	self.zorder = 0
	self.widgetDepth = -1
	self.branchSize = 1

	self.eventFilters = {}

	self.trackingPointer = false
	self.stringTableDict = false
end


function UIWidgetBase:getStringTableDict()
	local p = self
	while p do
		local d = p.stringTableDict
		if d then
			return d
		end
		p = p:getParentWidgetOrView()
	end
end

function UIWidgetBase:updateStringTable()
	local stringTableDict = self.stringTable and loadAsset( self.stringTable )
	if stringTableDict and isInstance( stringTableDict, DataSheetDictAccessor ) then
		self.stringTableDict = stringTableDict
	else
		self.stringTableDict = false
	end
	self:_updateTranslation()
end

function UIWidgetBase:_updateTranslation( forced )
	self:invalidateStyle()
	self:invalidateContent()
	for child in pairs( self:getChildren() ) do 
		if child.FLAG_UI_WIDGET then
			if forced or ( not child.stringTableDict ) then
				child:_updateTranslation( forced )
			end
		end
	end
end

function UIWidgetBase:translate( text, ... )
	local dict = self:getStringTableDict()
	if not dict then
		return text
	else
		return dict:getTranslated( text, ... )
	end
end

function UIWidgetBase:parseAndTranslate( text, ... )
	local function _translate( key )
		return self:translate( key ) or key
	end
	local result = string.gsub( text, '__%(([^)]*)%)', _translate )
	return result
end



function UIWidgetBase:invalidateContent()
end

function UIWidgetBase:invalidateVisual()
end

function UIWidgetBase:invalidateStyle()
end

function UIWidgetBase:isRootWidget()
	return false
end

function UIWidgetBase:getLocalStyleSheet()
	return self.localStyleSheetPath
end

function UIWidgetBase:setLocalStyleSheet( path )
	self.localStyleSheetPath = path
	self.localStyleSheet = path and loadAsset( path )
	self:clearInheritStyleSheet()
	self:onStyleSheetChanged()
end

function UIWidgetBase:getStyleSheetObject()
	local localStyleSheet = self.localStyleSheet
	if localStyleSheet then return localStyleSheet end
	local inheritedStyleSheet = self.inheritedStyleSheet
	if inheritedStyleSheet then return inheritedStyleSheet end
	--update inheritedStyleSheet
	local p = self.parent
	if p and p.FLAG_UI_WIDGET then
		inheritedStyleSheet = p:getStyleSheetObject()
		self.inheritedStyleSheet = inheritedStyleSheet
		return inheritedStyleSheet
	end
	return nil
end

function UIWidgetBase:refreshStyle()
	self.inheritedStyleSheet = false
	self.localStyleSheet = false
	if self.localStyleSheetPath then
		self:setLocalStyleSheet( self.localStyleSheetPath )
	else
		self:onStyleSheetChanged()
	end
end

function UIWidgetBase:clearInheritStyleSheet()
	self.inheritedStyleSheet = false
	for i, child in pairs( self.childWidgets ) do
		if not child.localStyleSheet then
			child:clearInheritStyleSheet()
		end
	end
	self:onStyleSheetChanged()
end

function UIWidgetBase:onStyleSheetChanged()
	
end

function UIWidgetBase:_setParentView( v )
	self._parentView = v
end

function UIWidgetBase:getParentView()
	return self._parentView
end

function UIWidgetBase:findParentWidgetOf( widgetType )
	local p = self.parent
	if not p then return false end
	if not p.FLAG_UI_WIDGET then return false end
	if p:isRootWidget() then return false end
	if p:isInstance( widgetType ) then return p end
	return p:findParentWidgetOf( widgetType )
end

function UIWidgetBase:getParentWidgetOrView()
	local p = self.parent
	if not p then return false end
	if not p.FLAG_UI_WIDGET then return false end
	return p
end

function UIWidgetBase:getParentWidget()
	local p = self.parent
	if not p then return false end
	if not p.FLAG_UI_WIDGET then return false end
	if p:isRootWidget() then return false end
	return p
end


function UIWidgetBase:getChildWidgetCount()
	return #self.childWidgets
end

function UIWidgetBase:getChildWidgets()
	return self.childWidgets
end

function UIWidgetBase:_updateBranchSize()
	local p = self
	while p do
		local size = 1
		for i, w in ipairs( p.childWidgets ) do
			size = size + w.branchSize
		end
		p.branchSize = size
		p = p:getParentWidget()
	end
end

function UIWidgetBase:_attachChildEntity( entity, layerName )
	if entity.FLAG_UI_WIDGET then
		table.insert( self.childWidgets, entity )
		if self._parentView then
			entity:_setParentView( self._parentView )
			-- self._parentView:invalidateZSorting()
		end
		self:sortChildren()
		self:_updateBranchSize()
		entity.widgetDepth = self.widgetDepth + 1
		entity:invalidateVisual()
		entity:updateFocusGroup()
	end	
	UIWidgetBase.__super._attachChildEntity( self, entity, layerName )
end

function UIWidgetBase:_detachChildEntity( entity )
	if entity.FLAG_UI_WIDGET then
		local idx = table.index( self.childWidgets, entity )
		if idx then
			table.remove( self.childWidgets, idx )
			entity.widgetDepth = -1
		end
		self:_updateBranchSize()
		entity:invalidateVisual()
	end	
	return UIWidgetBase.__super._detachChildEntity( self, entity )	
end

function UIWidgetBase:sortChildren()
	table.sort( self.childWidgets, widgetZSortFunc )
end

function UIWidgetBase:updateRenderOrder() --use loc z for priority now
	local z0 = self:getLocZ()
	local s = 1
	for i, widget in ipairs( self.childWidgets ) do
		widget:setLocZ( s * 0.001 )
		s = s + widget.branchSize
	end
end

function UIWidgetBase:getZOrder()
	return self.zorder
end

function UIWidgetBase:setZOrder( z )
	self.zorder = z
	local p = self.parent
	if p and p.FLAG_UI_WIDGET then
		return p:sortChildren()
	end
end

--------------------------------------------------------------------
function UIWidgetBase:postEvent( ev )
	local view = self._parentView
	if not view then return false end
	view:postEvent( self, ev )
end

function UIWidgetBase:sendEvent( ev, propagate )
	local needProc = true
	local filters = self.eventFilters
	local n = #filters
	for i = 1, n do
		local filter = filters[ i ]
		if filter( self, ev ) == false then 
			needProc = false
			break
		end
	end
	
	if needProc then
		self:procEvent( ev )
		self:onEvent( ev )
	end

	if self:isRootWidget() then return end 
	
	--propagate event to parent
	if not ev.accepted then
		local parent = self.parent
		if parent and parent.FLAG_UI_WIDGET then
			return parent:sendEvent( ev, true )
		end
	end
end

function UIWidgetBase:procEvent( ev )
end

function UIWidgetBase:onEvent( ev )
end

function UIWidgetBase:addEventFilter( filter )
	if not type( filter ) == 'function' then return end
	local idx = table.index( self.eventFilters, filter )
	if not idx then 
		table.insert( self.eventFilters, filter )
	else
		_warn( 'EventFilter already added', filter )
	end
end

function UIWidgetBase:removeEventFilter( filter )
	local idx = table.index( self.eventFilters, filter )
	if idx then 
		table.remove( self.eventFilters, idx )
	else
		_warn( 'filter not added', filter )
	end
end


--------------------------------------------------------------------
function UIWidgetBase:isInputEnabled()
	return self.inputEnabled
end

function UIWidgetBase:setInputEnabled( enabled )
	self.inputEnabled = enabled ~= false
end

function UIWidgetBase:isInteractive()
	return self.inputEnabled and self:isVisible() and self:isActive()
end

function UIWidgetBase:setTrackingPointer( tracking )
	self.trackingPointer = tracking ~= false
end

function UIWidgetBase:isTrackingPointer()
	return self.trackingPointer
end


--------------------------------------------------------------------
--------------------------------------------------------------------
CLASS: UIWidget ( UIWidgetBase )
	:MODEL{
		--- hide common entity properties
			Field '__gizmoIcon' :no_edit();
			-- Field 'rot'   :no_edit();
			Field 'scl'   :no_edit();
			-- Field 'piv'   :no_edit();
			Field 'layer' :no_edit();
		--------
		'----';
		Field 'loc'  :type( 'vec2' ) :meta{ decimals = 0 } :getset( 'LocXY'  ) :label( 'Loc'  );
		Field 'size' :type( 'vec2' ) :meta{ decimals = 0 } :getset( 'Size' ) :label( 'Size' );
		Field 'ZOrder' :int()  :getset( 'ZOrder' ) :label( 'Z-Order' );
		'----';
		Field 'layoutDisabled' :boolean() :label( 'Disable Layout' );
		Field 'createLayoutItem' :action( '_toolAffirmLayoutItem' );
		'----';
		Field 'defaultFeatures' :string() :getset( 'DefaultFeatures' );
		'----';
		Field 'defaultFocus' :boolean() ;
		Field 'focusGroup' :string() ;


	}

--------------------------------------------------------------------
function UIWidget:__init()
	self.styleAcc = UIStyleAccessor( self )

	self.w = 100
	self.h = 100
	self.overridedMetrics = {}

	self.FXHolder = UIWidgetFXHolder( self )
	
	self.focusPolicy = false
	self.focusGroup	 = false
	self.activeFocusGroup = false
	self.focusProxy  = false
	self.focusIndex = false
	self.defaultFocus = false
	self.clippingChildren = false

	self.layout = false
	self.localStyleSheetPath    = false


	self.layoutDisabled = false
	self.subWidget = false

	self.layoutPolicy     = { 'expand', 'expand' }
	self.layoutProportion = { 0, 0 }
	self.layoutAlignment  = { 'left', 'top' }

	self.margins = false
	self.spacing = false

	self.trackingPointer = true

	self.renderer = false
	self.rendererInited = false
	self.contentModified = true
	self.styleModified   = true
	self.layoutModified  = true

	self.defaultFeatures = ''

	self.focusConnections = {}

end

function UIWidget:setVisible( visible )
	local parent = self:getParentWidget()
	if parent then
		parent:invalidateLayout()
	end
	if not visible then
		self:blurFocus()
	end
	return UIWidget.__super.setVisible( self, visible )
end

function UIWidget:_attachChildEntity( entity, layerName )
	if entity:isInstance( UIWidget ) then
		self:invalidateLayout()
	end
	return UIWidget.__super._attachChildEntity( self, entity, layerName )	
end

function UIWidget:_detachChildEntity( entity )
	if entity:isInstance( UIWidget ) then
		self:invalidateLayout()
	end
	return UIWidget.__super._detachChildEntity( self, entity )	
end

function UIWidget:setZOrder( z )
	UIWidget.__super.setZOrder( self, z ) 
	return self:invalidateLayout()
end

function UIWidget:isSubWidget()
	return self.subWidget
end

function UIWidget:setSubWidget( subWidget )
	self.subWidget = subWidget and true or false
	self:invalidateVisual()
end

function UIWidget:getParentLayout()
	local p = self:getParentWidget()
	if not p then return false end
	return p:getLayout()
end

function UIWidget:getLayoutItem()
	return self:com( UILayoutItem )
end

function UIWidget:getLayoutEntry()
	local layoutItem = self:getLayoutItem()
	if layoutItem then
		return UILayoutEntry.fromLayoutItem( layoutItem )
	else
		return UILayoutEntry.fromWidget( self )
	end
end

function UIWidget:affirmRenderer()
	if not self.rendererInited then
		self:initRenderer()
	end
	return self.renderer
end

function UIWidget:getRenderer()
	return self.renderer
end

function UIWidget:setRenderer( r )
	local r0 = self.renderer
	if r0 then
		self:onRendererUnload( r0 )
		r0:destroy( self )
	end
	self.renderer = r
	if r then
		r:init( self )
		self:onRendererLoad( r )
	end

	if not self._updatingVisual then
		self:invalidateVisual()
	end
	self:invalidateLayout()
	return r
end

function UIWidget:onRendererLoad( renderer )
end

function UIWidget:onRendererUnload( renderer )
end

function UIWidget:onLoad()
	self:setState( 'normal' )
end


local function _getRendererClass( name )
	if not name then return false end
	local clas = findClass( name )
	if isSubclass( clas, UIWidgetRenderer ) then
		return clas
	else
		return false
	end
end

function UIWidget:initRenderer()
	if self.rendererInited then return end
	self.rendererInited = true
	
	--try get overrided renderer class from style
	local rendererClassName = self:getStyleAcc():get( 'renderer', false )
	local clas = 
		_getRendererClass( rendererClassName ) 
		or self:getDefaultRendererClass()

	if clas then
		self:setRenderer( clas() )
	end
end

function UIWidget:getDefaultRendererClass()
	return UICommonStyleWidgetRenderer
end

function UIWidget:_destroyNow()
	if self._parentView then
		self._parentView:onWidgetDestroyed( self )
		self._parentView = false
	end
	if self.renderer then
		self.renderer:destroy( self )
	end
	local parent = self.parent
	local childWidgets = parent and parent.childWidgets
	if childWidgets then
		for i, child in ipairs( childWidgets ) do
			if child == self then
				table.remove( childWidgets, i )
				break
			end
		end
	end
	if self._modal then
		self:setModal( false )		
	end
	return UIWidget.__super._destroyNow( self )
end


function UIWidget:setClippingChildren( clipping )
	self.clippingChildren = clipping
	return self:updateClippingRect()
end

function UIWidget:updateClippingRect()
	if not self.clippingChildren then 
		return self:setScissorRect()
	else
		return self:setScissorRect( self:getLocalRect() )
	end
end

--------------------------------------------------------------------
local function _findTopWidget( parent, x, y, padding )	
	local childId = 0
	local children = parent.childWidgets
	local count = #children
	for k = count , 1, -1 do
		local child = children[ k ]
		local px,py,pz = child:getWorldLoc()
		local pad = padding or child:getTouchPadding()
		local inside = child:inside( x, y, pz, pad )
		if inside == 'group' then
			local found = _findTopWidget( child, x, y, padding )
			if found then	return found end
		elseif inside then
			local result = _findTopWidget( child, x, y, padding ) or child
			return result
		end
	end
	return nil
end

function UIWidget:findTopWidget( x, y, pad )
	return _findTopWidget( self, x, y, pad )
end


--------------------------------------------------------------------
--Focus control
function UIWidget:isFocusable()
	if self.FLAG_INTERNAL then return false end
	local policy = self.focusPolicy or 'none'
	if policy == 'none' then return false end	
	return true
end

function UIWidget:setFocusProxy( widget )
	self.focusProxy = widget
end

function UIWidget:getFocusProxy()
	return self.focusProxy
end

function UIWidget:setFocusGroup( g )
	self.focusGroup = g
	if self:isFocusable() then
		local view = self:getParentView()
		if view then
			self:updateFocusGroup()
		end
	end
	-- self:updateFocusGroup()
end

function UIWidget:getFocusGroup()
	local g = self.focusGroup
	if g then return g end
	local p = self:getParentWidget()
	while p do
		if p.focusGroup then return p.focusGroup end
		p = p:getParentWidget()
	end
	return false
end

function UIWidget:_updateFocusGroup( focusManager, defaultGroup )
	local group = self.focusGroup or defaultGroup
	if self:isFocusable() then
		focusManager:registerFocusableWidget( self, group )
	end
	for i, child in ipairs( self.childWidgets ) do
		if not child.FLAG_INTERNAL then
			child:_updateFocusGroup( focusManager, group )
		end
	end
end

function UIWidget:updateFocusGroup()
	local view = self:getParentView()
	if not view then return end
	local focusManager = view.focusManager
	return self:_updateFocusGroup( focusManager, self:getFocusGroup() )
end

function UIWidget:hasFocus()
	local focused = self._parentView:getFocusedWidget()
	return focused == self
end

function UIWidget:getDefaultFocusableChild()
	for i, child in ipairs( self.childWidgets ) do
		child:forceUpdate() --update visible state	
		if ( not child.FLAG_INTERNAL ) and child:isActive() and child:isVisible() then
			if child:isFocusable() and child.defaultFocus then
				return child
			else
				local w = child:getDefaultFocusableChild()
				if w then return w end
			end
		end
	end
end

function UIWidget:hasParentFocus()
	local focused = self._parentView:getFocusedWidget()
	return focused and focused:isParentOf( self )
end

function UIWidget:hasParentOrSelfFocus()
	local focused = self._parentView:getFocusedWidget()
	return focused and ( fosued == self or focused:isParentOf( self ) )
end

function UIWidget:hasChildFocus()
	local focused = self._parentView:getFocusedWidget()
	return focused and focused:isChildOf( self )
end

function UIWidget:isHovered()
	local view = self._parentView
	return view:getMousePointer():getHoverWidget() == self
end

function UIWidget:setFocus( reason )
	local view = self._parentView
	if view then
		return view:setFocusedWidget( self, reason )
	end
end

function UIWidget:blurFocus( reason )
	local view = self._parentView
	if not view then return end
	local focused = view:getFocusedWidget()
	if not focused then return end
	
	if focused == self or focused:isChildOf( self ) then
		view:setFocusedWidget( false, reason )
	end

end

function UIWidget:setFocusPolicy( policy )
	if policy == false then policy = 'none' end
	self.focusPolicy = policy or 'normal'
	self:updateFocusGroup()
end


local _arrow2dir = {
	up    = 'n';
	down  = 's';
	right = 'e';
	left  = 'w';
}

function UIWidget:setFocusConnection( dir, widget )
	dir = ( dir and _arrow2dir[ dir ] ) or dir or 'next'
	self.focusConnections[ dir ] = widget
end

function UIWidget:getFocusConnection( dir )
	dir = ( dir and _arrow2dir[ dir ] ) or dir
	local widget = self
	while true do
		local found = widget.focusConnections[ dir ]
		if not found then break end
		if found:isVisible() then return found end
		widget = found
	end
	--use builtin geometry solution
	return self:getParentView().focusManager:findFocusConnection( self, dir )
end


function UIWidget:moveFocus( dir, reason )
	dir = ( dir and _arrow2dir[ dir ] ) or dir or 'next'
	local target = self:getFocusConnection( dir )
	if target then
		target:setFocus( reason )
	end
end

function UIWidget:setModal( modal )
	modal = modal ~= false
	if self._modal == modal then return end
	self._modal = modal
	if self._parentView then
		if modal then 
			self._parentView:setModalWidget( self )
		else
			if self._parentView:getModalWidget() == self then
				self._parentView:setModalWidget( nil )
			end
		end
	end
end

function UIWidget:isModalChild()
	if not self._parentView then return false end
	local modalWidget = self._parentView:getModalWidget()
	if not modalWidget then return true end
	if modalWidget == self then return true end
	return self:isChildOf( modalWidget )
end

--------------------------------------------------------------------
function UIWidget:getContentData( key, role )
	return nil
end

function UIWidget:ensureVisible( instant )
	local p = self:getParentWidget()
	while p do
		p:ensureWidgetVisible( self, instant )
		p = p:getParentWidget()
	end
end

function UIWidget:ensureWidgetVisible( w, instant )
end

--------------------------------------------------------------------
function UIWidget:getStyleAcc()
	self.styleAcc:update()
	return self.styleAcc
end

--------------------------------------------------------------------
function UIWidget:getDefaultFeatures()
	return self.defaultFeatures
end

function UIWidget:setDefaultFeatures( f )
	local tt = type( f )
	local features
	if tt == 'string' then
		features = f:split( ',', true )
		self.defaultFeatures = f
	elseif tt == 'table' then
		features = f
	else
		_warn( 'invalid features type', tt )
		return false
	end
	return self:setFeatures( features )
end

function UIWidget:getCursor( default )
	self.styleAcc:update()
	return self.styleAcc:get( 'cursor', default or 'default' )
end

function UIWidget:getFeatures()
	return self.styleAcc.features
end

function UIWidget:setFeatures( features )
	self.styleAcc:setFeatures( features )
	return self:invalidateStyle()
end

function UIWidget:clearFeatures()
	self.styleAcc:setFeatures( false )
	return self:invalidateStyle()
end

function UIWidget:hasFeature( feature )
	return self.styleAcc:hasFeature( feature )
end

function UIWidget:setFeature( feature, bvalue )
	self.styleAcc:setFeature( feature, bvalue ~= false )
	return self:invalidateStyle()
end

function UIWidget:addFeature( feature )
	return self:setFeature( feature, true )
end

function UIWidget:removeFeature( feature )
	return self:setFeature( feature, false )
end

function UIWidget:toggleFeature( feature )
	return self:setFeature( feature, not self:hasFeature( feature ) )
end

function UIWidget:invalidateContent()
	self.contentModified = true
	return self:invalidateVisual()
end

function UIWidget:invalidateVisual()
	local view = self:getParentView()
	if not view then return end
	return view:scheduleVisualUpdate( self )
end

function UIWidget:invalidateStyle()
	local view = self:getParentView()
	if not view then return end
	self.styleAcc:markDirty()
	--invalidate children
	for i, child in ipairs( self.childWidgets ) do
		child:invalidateStyle()
	end
end

function UIWidget:updateVisual()
	self._updatingVisual = true
	local style = self.styleAcc
	style:update()

	--check layout related property
	local margin = style:getBox( 'margin' )
	if margin  then self:setMargin( unpack( margin ) ) end

	local spacing = style:getBox( 'spacing' )
	if spacing then self:setSpacing( unpack( spacing ) ) end

	local contentModified = self.contentModified
	local styleModified = self.styleModified
	self.contentModified = false
	self.styleModified = false
	
	local renderer = self:affirmRenderer()
	if renderer then
		renderer:update( self, style, styleModified, contentModified )
	end
	self.FXHolder:updateVisual( style )
	self:onUpdateVisual( style )
	self:updateClippingRect()	
	self._updatingVisual = false
end

function UIWidget:onUpdateVisual( style )
	self:updateCommonStyle( style )
end

function UIWidget:updateCommonStyle( style )
	--TODO:margin
	--TODO:padding
	--TODO:color
end

--------------------------------------------------------------------
--geometry
function UIWidget:getViewLoc()
	local wx, wy, wz = self:getWorldLoc()
	local view = self:getParentView()
	if view then
		return view:worldToModel( wx, wy, wz )
	else
		return wx, wy, wz
	end
end


function UIWidget:getWorldBounds( reason )
	return self:getProp():getWorldBounds()
end

function UIWidget:inside( x, y, z, pad )
	local bx0, by0, bz0, bx1, by1, bz1 = self:getWorldBounds()
	if not bx0 then return false end
	if pad then
		return 
			( x + pad >= bx0 ) and ( x - pad <= bx1 )
			and 
			( y + pad >= by0 ) and ( y - pad <= by1 )
	else
		return 
			( x >= bx0 ) and ( x <= bx1 )
			and 
			( y >= by0 ) and ( y <= by1 )
	end
end

function UIWidget:setSize( w, h, updateLayout, updateStyle )
	w, h = w or self.w, h or self.h
	w = math.max( w, 0 )
	h = math.max( h, 0 )
	if self.w == w and self.h == h then return end
	self.w, self.h = w, h
	local x0,y0,x1,y1 = self:getLocalRect()
	self:getProp():setBounds( x0,y0, 0, x1,y1, 1 )
	if updateLayout ~= false then
		self:invalidateLayout()
	end
	if updateStyle ~= false then
		self:invalidateVisual()
	end
	self:updateClippingRect()
	self:postEvent( UIEvent( UIEvent.RESIZE, { size = { w, h } } ) )
end

function UIWidget:setHeight( h )
	return self:setSize( self.w, h )
end

function UIWidget:setWidth( w )
	return self:setSize( w, self.h )
end
function UIWidget:getSize()
	return self.w, self.h
end

function UIWidget:getLocalRect()
	local w, h = self:getSize()
	return 0, -h, w, 0
end

function UIWidget:getInnerSize()
	local w, h = self:getSize()
	local sl, st, sr, sb = self:getSpacing()
	return w - sl - sr, h - st - sb
end

function UIWidget:getInnerRect() --minus spacing
	local sl, st, sr, sb = self:getSpacing()
	local x0, y0, x1, y1 = self:getLocalRect()
	return x0 + sl, y0 + st, x1 - sr, y1 - sb
end

function UIWidget:getLocalCenter()
	local x0, y0, x1, y1 = self:getLocalRect()
	return ( x0 + x1 ) / 2, ( y0 + y1 ) / 2
end

function UIWidget:getRect()
	return self:getLocalRect()
end

function UIWidget:getWorldRect()
	local x0,y0,x1,y1 = self:getRect()
	x0,y0 = self:modelToWorld( x0,y0 )
	x1,y1 = self:modelToWorld( x1,y1 )
	return x0,y0,x1,y1
end

function UIWidget:getFocusRect()
	return self:getWorldRect()
end

function UIWidget:getFocusCenter()
	local x0,y0,x1,y1 = self:getFocusRect()
	return ( x0 + y0 )/ 2, ( x1 + y1 )/ 2
end


function UIWidget:getGeometry()
	local x, y = self:getLoc()
	local w, h = self:getSize()
	return x, y, w, h
end

function UIWidget:setGeometry( x, y, w, h, updateLayout, updateStyle )
	self:setLocX( x )
	self:setLocY( y )
	self:setSize( w, h, updateLayout, updateStyle )
end

function UIWidget:getContentSize()
	--TODO:
	local renderer = self:getRenderer()
	if renderer then 
		return renderer:getContentSize()
	else
		return self:getSize()
	end
end

--------------------------------------------------------------------
--layout
function UIWidget:setLayout( l )
	if l then
		assert( not l.widget )
		self.layout = l
		l:setOwner( self )
		self:invalidateLayout()
		return l
	else
		self.layout = false
	end
end

function UIWidget:getLayout()
	return self.layout
end

local function _findLayoutParent( widget )
	local p = widget
	while p do
		local p1 = p:getParentWidget()
		if not ( p1 and p1.layout ) then break end
		p = p1
	end
	return p
end

local function _invalidateSelfAndChildrenLayout( view, widget )
	view:scheduleLayoutUpdate( widget )
	for i, child in ipairs( widget.childWidgets ) do
		if child.layout then
			_invalidateSelfAndChildrenLayout( view, child )
		end
	end
end

function UIWidget:invalidateLayout()
	self.layoutModified = true
	local view = self:getParentView()
	if not view then return end
	local p = _findLayoutParent( self )
	if p then
		return _invalidateSelfAndChildrenLayout( view, p )
	end
end

function UIWidget:updateLayout()
	self._updatingLayout = true
	self.layoutModified = false
	self:updateRenderOrder()

	local layout = self.layout 
	if not layout then 
		self._updatingLayout = false
		return
	end
	layout:update()
	self:invalidateVisual()
	self._updatingLayout = false
end

function UIWidget:getLayoutPolicy()
	return unpack( self.layoutPolicy )
end

function UIWidget:setLayoutPolicy( h, v )
	self.layoutPolicy = { h, v }
	self:invalidateLayout()
end

function UIWidget:getLayoutAlignment()
	return unpack( self.layoutAlignment )
end

function UIWidget:setLayoutAlignment( h, v )
	self.layoutAlignment = { h, v }
	self:invalidateLayout()
end

function UIWidget:getLayoutProportion()
	return unpack( self.layoutProportion )
end

function UIWidget:setLayoutProportion( h, v )
	self.layoutProportion = { h, v }
	self:invalidateLayout()
end

function UIWidget:getChildLayoutEntries()
	local result = {}
	for i, widget in ipairs( self.childWidgets ) do
		if ( not widget.layoutDisabled ) 
			and ( not widget.FLAG_INTERNAL ) 
			and widget:isLocalVisible() 
		then
			local entry = widget:getLayoutEntry()
			insert( result, entry )
		end
	end
	return result
end

--------------------------------------------------------------------
function UIWidget:getMinSizeHint( widthLimit, heightLimit )
	return 0,0
end

function UIWidget:getMaxSizeHint( widthLimit, heightLimit )
	return -1,-1
end

function UIWidget:getMarginHint()
	return 0,0,0,0
end

function UIWidget:getSpacingHint()
	return 0,0,0,0
end

local function _eqBox( t, a,b,c,d )
	if not t then return false end
	local a1,b1,c1,d1 = t[1], t[2], t[3], t[4]
	return a1 == a and b1 == b and c1 == c and d1 == d
end

function UIWidget:setSpacing( l, t, r, b )
	if not l then
		self.overridedMetrics.spacing = false
	else
		if _eqBox( self.overridedMetrics.spacing, l,t,r,b ) then return end
		self.overridedMetrics.spacing = { l, t, r, b }
	end
	self:invalidateLayout()
end

function UIWidget:getSpacing()
	local spacing = self.overridedMetrics.spacing
	if spacing then
		return unpack( spacing )
	else
		return self:getSpacingHint()
	end
end

function UIWidget:setMargin( l, t, r, b )
	if not l then
		self.overridedMetrics.margin = false
	else
		if _eqBox( self.overridedMetrics.margin, l,t,r,b ) then return end
		self.overridedMetrics.margin = { l, t, r, b }
	end
	self:invalidateLayout()
end

function UIWidget:getMargin()
	local margin = self.overridedMetrics.margin
	if margin then
		return unpack( margin )
	else
		return self:getMarginHint()
	end
end

function UIWidget:getMinSize()
	local min = self.overridedMetrics.min
	if min then
		return min[1], min[2]
	else
		return self:getMinSizeHint( false, false )
	end
end

function UIWidget:getMaxSize()
	local overridedMetrics = self.overridedMetrics
	local max = self.overridedMetrics.max
	if max then
		return max[1], max[2]
	else
		return self:getMaxSizeHint( false, false )
	end
end

function UIWidget:getWidth()
	local w, h = self:getSize()
	return w
end

function UIWidget:getHeight()
	local w, h = self:getSize()
	return h
end

function UIWidget:getFixedSize()
	local size = self.overridedMetrics.fixed
	if size then
		return size[1], size[2]
	else
		return 0, 0
	end
end

function UIWidget:getFixedWidth()
	local w, h = self:getFixedSize()
	return w
end

function UIWidget:getFixedHeight()
	local w, h = self:getFixedSize()
	return h
end

function UIWidget:getMaxWidth()
	local w, h = self:getMaxSize()
	return w
end

function UIWidget:getMaxHeight()
	local w, h = self:getMaxSize()
	return h
end

function UIWidget:getMinWidth()
	local w, h = self:getMinSize()
	return w
end

function UIWidget:getMinHeight()
	local w, h = self:getMinSize()
	return h
end


function UIWidget:setFixedSize( w, h )
	if not w then
		self.overridedMetrics.fixed = false
	else
		self.overridedMetrics.fixed = { w, h }
	end
	self:invalidateLayout()
end

function UIWidget:setMinSize( w, h )
	if not w then
		self.overridedMetrics.min = false
	else
		self.overridedMetrics.min = { w, h }
	end
	self:invalidateLayout()
end

function UIWidget:setMaxSize( w, h )
	if not w then
		self.overridedMetrics.max = false
	else
		self.overridedMetrics.max = { w, h }
	end
	self:invalidateLayout()
end

function UIWidget:setMinHeight( h )
	local w0 = self:getMinWidth()
	return self:setMinSize( w0, h )
end

function UIWidget:setMinWidth( w )
	local h0 = self:getMinHeight()
	return self:setMinSize( w, h0 )
end

--------------------------------------------------------------------
function UIWidget:updateStyleState()
	self:setState( 'normal' )
end

function UIWidget:onSetActive( active )
	if active then
		self:updateStyleState()
	else
		self:setState( 'disabled' )	
	end
end

function UIWidget:setState( state )
	local ps = self.state
	if state ~= ps then
		--change state
		self.styleAcc:setState( state )
		self:invalidateStyle()
	end
	return UIWidget.__super.setState( self, state )
end

function UIWidget:onStateChange( state )
end

--------------------------------------------------------------------
--audio
function UIWidget:tryPlaySound( name )
	local view = self:getParentView()
	if not view then return false end
	return view:tryPlaySoundFor( self, name )
end

--------------------------------------------------------------------
--extra
function UIWidget:getTouchPadding()
	return DEFAULT_TOUCH_PADDING
end

--------------------------------------------------------------------
--editor
function UIWidget:onBuildGizmo( )
	return mock_edit.DrawScriptGizmo()	
end

function UIWidget:onDrawGizmo( selected )
	GIIHelper.setVertexTransform( self:getProp() )
	MOAIDraw.setPenColor( hexcolor('#fc0bff', selected and 0.9 or 0.4 ) )
	MOAIDraw.drawRect( self:getLocalRect() )
end

function UIWidget:onStyleSheetChanged()
	self:invalidateStyle()
end

function UIWidget:affirmLayoutItem()
	local layoutItem  = self:com( UILayoutItem )
	if layoutItem then return layoutItem end
	local layout = self:getParentLayout()
	if layout then
		layoutItem = layout:createLayoutItem()
	else
		layoutItem = UILayoutItem()
	end
	self:attach( layoutItem )
	return layoutItem
end

function UIWidget:_toolAffirmLayoutItem()
	if not self:com( UILayoutItem ) then
		local item = self:affirmLayoutItem()
		gii.emitPythonSignal( 'component.added', item, self )	
	end
end

function UIWidget:raise()
	self:show()
	if not ( self:hasFocus() or self:hasChildFocus() ) then self:setFocus() end
end

function UIWidget:fitContent()
	--todo
end

