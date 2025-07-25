/**
 *与webview交互
 */
 
var webViewBridge,webViewCall;
	
function connectWebViewJavascriptBridge(callback) {
	if (window.WebViewJavascriptBridge) { return callback(WebViewJavascriptBridge); }
	if(window.location.href.indexOf('http')==0){
		window.WebViewJavascriptBridge={
			registerHandler:function(bridge,responseCallback){
				app.trigger(responseCallback,{success:true,action:'setData',data:'111'});
			},
			callHandler:function(bridge,data,responseCallback){
				app.trigger(responseCallback,{success:true});
			}
		};
		return callback(WebViewJavascriptBridge);
	};
	if(isIos){
		if (window.WVJBCallbacks) { return window.WVJBCallbacks.push(callback); }
		window.WVJBCallbacks = [callback];
		var WVJBIframe = document.createElement('iframe');
		WVJBIframe.style.display = 'none';
		WVJBIframe.src = 'wvjbscheme://__BRIDGE_LOADED__';		
		var ready=setTimeout(function(){
			document.documentElement.removeChild(WVJBIframe);
			document.addEventListener('WebViewJavascriptBridgeReady', function() {
				callback(WebViewJavascriptBridge);
			}, false);
		},50);
		
		WVJBIframe.onload=function(){
			document.documentElement.removeChild(WVJBIframe);
			clearTimeout(ready);
		};
		document.documentElement.appendChild(WVJBIframe);
	}else{
		document.addEventListener('WebViewJavascriptBridgeReady', function() {
			callback(WebViewJavascriptBridge);
		}, false);
	};	
};
wx.app.connect=function(callback){
		console.log('[webviewbridge.js] wx.app.connect 被调用');
		// 添加全局标记，表示connect已被调用
		window._wxAppConnecting = true;
		connectWebViewJavascriptBridge(function(bridge) {
		
		console.log('[webviewbridge.js] 桥接建立成功');
		webViewBridge=bridge;
		window._wxAppConnected = true;
		
		bridge.registerHandler('xzBridge', function(backData, responseCallback) {
			 console.log('[webviewbridge.js] 收到原生调用:', backData.action, backData.data);
			 
			if(!backData.action||!wx.app.on[backData.action]){
				console.error('[webviewbridge.js] action未定义:', backData.action);
				app.trigger(responseCallback,{
					success:false,
					errorMessage:backData.action+' is undefined'
				});
				return;
			};
			wx.app.on[backData.action](backData.data,responseCallback);
		 
		});
			
		webViewCall=function(action,obj){
			 console.log('[webviewbridge.js] 调用原生方法:', action, obj);
			 
			 if(typeof obj=='function'){
				 obj={
					 success:obj
					 };
			 };
			
			 obj=app.extend(true,{
							success:app.noop,
							fail:app.noop,
							complete:app.noop,
							data:''
					 },obj);
			 
			 
			 bridge.callHandler('xzBridge',{action:action,data:obj.data},function(backData){
				 console.log('[webviewbridge.js] 收到响应:', action, backData);
				 if(backData.success&&backData.success!='false'){
					
					 app.trigger(obj.success,backData.data||{});
				 }else{
					 console.error('[webviewbridge.js] 调用失败:', action, backData.errorMessage);
					 app.trigger(obj.fail,backData.errorMessage);
				 };
				  app.trigger(obj.complete,backData);
			 });
		};
		wx.app.call=webViewCall;
		console.log('[webviewbridge.js] 发送 pageReady');
		webViewCall('pageReady');
		app.trigger(callback);
	});
};
	