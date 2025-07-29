(function() {

    let app = getApp();

    app.Page({
        pageId: 'user-setting',
        data: {
            systemId: 'user',
            moduleId: 'setting',
			isUserLogin: app.checkUser(),
            data: {},
            options: {},
            settings: {},
            language: {},
            client: app.config.client,
            form: {},
			versionCode:'',
        },
        methods: {
            onLoad:function(options){
				let _this=this;
				_this.setData({options:options});
				app.checkUser(function(){
					_this.setData({isUserLogin:true});
				});
				if(app.config.client=='app'){
					app.request('//set/get',{type:'appSet'},function(res){
						let backData = res.data||{};
						if(backData){
							_this.setData({
								versionCode:backData.versionCode
							});
						};
					});
				};
			},
			onShow: function(){
				//检查用户登录状态
				let isUserLogin=app.checkUser();
				if(isUserLogin!=this.getData().isUserLogin){
					this.setData({isUserLogin:isUserLogin});
					
				};
			},
			onPullDownRefresh: function() {
				wx.stopPullDownRefresh();
			},
            signOut: function(e) {
                let _this = this;
                app.confirm('确定要退出登录吗?', function () {
                    app.request('//userapi/logout', function () {
                        app.removeUserSession();
						app.tips('退出成功','success');
						setTimeout(function(){
							app.reLaunch('../../home/index/index');
						},1000);
                    });
                })

            }
        }
    });
})();