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
			copyThis: function (e) {//复制内容
				let client = app.config.client,
					content = '公司名称：上海在局信息科技有限公司\n税号：91310120MAE6JMD71G\n地址：上海市奉贤区望园南路1288弄80号1904、1909室\n电话：021-80392125\n银行账号：1219 8013 0510 006\n开户银行：招商银行股份有限公司上海张江支行\n发票类型：3个点或者6个点增值税专用发票\n发票类目：服务费';
				if (client == 'wx') {
					wx.setClipboardData({
						data: content,
						success: function () {
							app.tips('复制成功', 'error');
						},
					});
				} else if (client == 'app') {
					wx.app.call('copyLink', {
						data: {
							url: content
						},
						success: function (res) {
							app.tips('复制成功', 'error');
						}
					});
				} else {
					$('body').append('<input class="readonlyInput" value="'+content+'" id="readonlyInput" readonly />');
					  var originInput = document.querySelector('#readonlyInput');
					  originInput.select();
					  if(document.execCommand('copy')) {
						  document.execCommand('copy');
						  app.tips('复制成功','error');
					  }else{
						  app.tips('浏览器不支持，请手动复制','error');
					  };
					  originInput.remove();
				};
			},
		}
	});
})();