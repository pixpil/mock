module 'mock'

EnumAnimCurveTweenMode = {
	{ 'constant'          , MOAIAnimCurveEX.SPAN_MODE_CONSTANT          };
	{ 'linear'            , MOAIAnimCurveEX.SPAN_MODE_LINEAR            };
	{ 'bezier'            , MOAIAnimCurveEX.SPAN_MODE_BEZIER            };
}

--------------------------------------------------------------------
require 'mock.anim.AnimatorTargetId'
require 'mock.anim.AnimatorState'
require 'mock.anim.AnimatorClip'
require 'mock.anim.AnimatorData'
require 'mock.anim.Animator'
require 'mock.anim.EmbedAnimator'
require 'mock.anim.AnimatorEditorSupport'

--------------------------------------------------------------------
--value tracks
require 'mock.anim.AnimatorEventTrack'
require 'mock.anim.AnimatorValueTrack'
require 'mock.anim.CustomAnimatorTrack'

--------------------------------------------------------------------
require 'mock.anim.AnimatorTrackAttr'

--------------------------------------------------------------------
require 'mock.anim.AnimatorTrackField'
	require 'mock.anim.AnimatorTrackFieldNumber'	
	require 'mock.anim.AnimatorTrackFieldInt'	
	require 'mock.anim.AnimatorTrackFieldVec'
	require 'mock.anim.AnimatorTrackFieldColor'
	require 'mock.anim.AnimatorTrackFieldDiscrete'
	require 'mock.anim.AnimatorTrackFieldBoolean'
	require 'mock.anim.AnimatorTrackFieldString'
	require 'mock.anim.AnimatorTrackFieldEnum'
	require 'mock.anim.AnimatorTrackFieldAsset'
	-- require 'mock.anim.AnimatorTrackFieldObjRef'

	function getAnimatorTrackFieldClass( ftype )
		if ftype == 'number' then
			return AnimatorTrackFieldNumber
		elseif ftype == 'int' then
			return AnimatorTrackFieldInt	
		elseif ftype == 'boolean' then
			return AnimatorTrackFieldBoolean
		elseif ftype == 'string' then
			return AnimatorTrackFieldString
		elseif ftype == 'vec2' then
			return AnimatorTrackFieldVec2
		elseif ftype == 'vec3' then
			return AnimatorTrackFieldVec3
		elseif ftype == 'color' then
			return AnimatorTrackFieldColor
		elseif ftype == '@asset' then
			return AnimatorTrackFieldAsset
		elseif ftype == '@enum' then
			return AnimatorTrackFieldEnum
		end
		return false
	end
--------------------------------------------------------------------

--------------------------------------------------------------------
--builtin custom track
--------------------------------------------------------------------
require 'mock.anim.tracks.AnimatorAnimatorTrack'
require 'mock.anim.tracks.EntityMsgAnimatorTrack'
require 'mock.anim.tracks.ScriptAnimatorTrack'
