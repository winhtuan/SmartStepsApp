{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Remove the loading spinner once the engine is initialized
    const spinner = document.getElementById('loading-indicator');
    if (spinner) {
      spinner.remove();
    }
    
    await appRunner.runApp();
  }
});
