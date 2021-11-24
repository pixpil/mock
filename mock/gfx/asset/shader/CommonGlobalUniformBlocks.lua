module 'mock'

CLASS: GlobalUniformBlockViewSize ( GlobalUniformBlock )
:register( 'view_size' )

function GlobalUniformBlockViewSize:onInit( buffer )
	local format = createUniformFormat{
		{ name = 'viewWidth',  type = 'float' },
		{ name = 'viewHeight', type = 'float' },
	}
	buffer:setFormat( format )
end

