module 'mock'

---------------------------------------------------------------------
CLASS: TesterInfo ()

function TesterInfo:__init()
	self.GUID       = false
	self.name       = 'ananoymous'
	self.age        = 0
	self.gender     = 'M'
	self.occupation = false
	self.language   = 'en'
	
end


--------------------------------------------------------------------
CLASS: TesterReportManager ( GlobalManager )
	:MODEL{}

function TesterReportManager:__init()
	-- body
end

--------------------------------------------------------------------
CLASS: TesterReport ()
	:MODEL{}