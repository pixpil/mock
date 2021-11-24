module 'mock'

-- --------------------------------------------------------------------
-- CLASS: UIItemData ()
-- 	:MODEL{}

-- function UIItemData:getData( key, role )
-- 	return nil
-- end

-- function UIItemData:setData( key, role( ... )
-- 	-- body
-- end

CLASS: UIComboBoxDataItem ()
	:MODEL{}

function UIComboBoxDataItem:__init( text, data )
	self.idx = false
	self.text = text
	self.data = ata
end

--------------------------------------------------------------------
CLASS: UIComboBox ( UIWidget )
	:MODEL{}
	:SIGNAL{
		selection_changed = 'onSelectionChanged';
	}

mock.registerComponent( 'UIComboBox', UIComboBox )
--mock.registerEntityWithComponent( 'UIComboBox', UIComboBox )

function UIComboBox:__init()
	self.currentOption = 0
	self.items = {}
end

function UIComboBox:clear()
	self.items = {}
	self:refresh()
end

function UIComboBox:getSelection()
end

function UIComboBox:refresh()
end

function UIComboBox:onSelectionChanged( selection )
end

