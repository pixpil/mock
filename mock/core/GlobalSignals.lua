module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'msg',
	'app.start',
	'app.resume',
	'app.end',
	'app.focus_change',
	'app.env_change',
	'app.overlay.on',
	'app.overlay.off',
	
	'game.init',
	'game.start',
	'game.ready',
	'game.pause',
	'game.resume',
	'game.debug_level_change',
	'scene_root.pause',
	'scene_root.resume',
	'game.stop',
	'game.commit_savedata',

	'asset.init',

	'asset.script_modified',

	'gfx.resize',
	'device.resize',
	'gfx.fullscreen_change',
	'gfx.context_ready',
	'gfx.render_manager_ready',
	'gfx.pre_sync_render_state',
	'gfx.post_sync_render_state',
	'gfx.performance_profile.change',

	'mainscene.schedule_open',
	'mainscene.open',
	'mainscene.start',
	'mainscene.stop',
	'mainscene.close',

	'scene.schedule_open',
	'scene.open',
	'scene.start',
	'scene.stop',
	'scene.close',	

	'scene.init',
	'scene.update',
	'scene.clear',

	'scene_session.add',
	'scene_session.remove',

	'layer.update',
	'layer.add',
	'layer.remove',

	'game_config.save',
	'game_config.load',

	'input.joystick.add',
	'input.joystick.remove',
	'input.joystick.assign',

	'input.mouse.mode_change',

	'input.source.change',
	'input.mapping.change',
}

