/**
 *模块组件构造器
 */
(function() {

	let app = getApp();

	app.Page({
		pageId: 'finance-withdrawInvoice',
		data: {
			systemId: 'finance',
			moduleId: 'withdrawInvoice',
			isUserLogin: app.checkUser(),
			data: {},
			options: {},
			settings: {},
			language: {},
			form: {
				id:'',
				pic:''
			},
			picWidth:(app.system.windowWidth>480?480:app.system.windowWidth)-30,
			picHeight:((app.system.windowWidth>480?480:app.system.windowWidth)-30)/1.6,
		},
		methods: {
			onLoad: function(options) {
				let _this = this;
				_this.setData({
					options: options,
					'form.id':options.id,
				});
				app.checkUser(function() {
					_this.setData({
						isUserLogin: true
					});
					_this.load();
				});
			},
			onShow: function() {
				//检查用户登录状态
				let isUserLogin = app.checkUser();
				if (isUserLogin != this.getData().isUserLogin) {
					this.setData({
						isUserLogin: isUserLogin
					});
					if (isUserLogin) {
						this.load();
					};
				};
			},
			onPullDownRefresh: function() {
				if (this.getData().isUserLogin) {
					this.load();
				};
				wx.stopPullDownRefresh();
			},
			load: function() {
				
			},
			uploadSuccess: function(e) {
				this.setData({
					'form.pic': e.detail.src[0]
				});
            },
			submit: function(e) {
				let _this = this, 
					formData = _this.getData().form,
					msg = '';
				if(!formData.pic) {
					msg = '请上传电子发票';
				};
				if (msg) {
					app.tips(msg,'error');
				} else {
					app.request('//financeapi/addWithInvoice', formData, function(res) {
						app.tips('提交成功', 'success');
						setTimeout(app.navBack,1000);
					});
				};
			},
		}
	});
})();