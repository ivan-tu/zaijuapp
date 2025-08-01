/**
 *模块组件构造器
 */
(function() {

	let app = getApp();

	app.Page({
		pageId: 'finance-withdrawDetail',
		data: {
			systemId: 'finance',
			moduleId: 'withdrawDetail',
			isUserLogin: app.checkUser(),
			data: {},
			options: {},
			settings: {},
			language: {},
			form: {},
			checkTimeText:'',
		},
		methods: {
			onLoad: function(options) {
				let _this = this;
				_this.setData({
					options: options
				});
			},
			onShow: function() {
				let _this = this;
				app.checkUser(function() {
					_this.setData({
						isUserLogin: true
					});
					_this.load();
				});
			},
			onPullDownRefresh: function() {
				if (this.getData().isUserLogin) {
					this.load();
				};
				wx.stopPullDownRefresh();
			},
			load: function() {
				let _this = this,
					checkTimeText = '',
					options = this.getData().options;
				app.request('//financeapi/getApplyInfo', options, function(res) {
					if(res){
						res.checkTimeText = '预计审核时间：'+_this.getCheckDate(res.addtime);
						//是钻石提现，是企业，并且没提交过
						if(res.type=='8'&&res.banktype=='company'&&!res.invoice){
							res.needInvoice = 1;
						}else{
							res.needInvoice = 0;
						};
						if(res.invoice){
							res.invoice = app.image.width(res.invoice,200);
						};
						_this.setData({
							data: res
						});
					};
				});
			},
			getCheckDate:function(date){//根据日期，获取预计审核日期
				let _this = this;
				if(!date)return;
				date = date.replace(/-/g, '/');
				let newDate = (new Date(date)).getTime(),
					week = (new Date(date)).getDay(),
					addTime = 0;
				switch(week){
					case 5://星期五
					addTime = 3;
					break;
					case 6://星期六
					addTime = 2;
					break;
					default:
					addTime = 1;
				};
				return app.getThatDate(newDate,addTime);
			},
			adopt: function() {
				let _this = this, 
					data = _this.getData().data;
				app.confirm('确认已邮寄发票吗？', function() {
					app.request('//financeapi/updateInvoicestatus', {
						id: data.id
					}, function() {
						app.tips('操作成功');
						_this.setData({
							'data.invoicestatus': 1
						});
					});
				});
			},
			toCancel:function(){
				let _this = this, 
					data = _this.getData().data;
				app.confirm('确定要撤销吗？', function() {
					app.request('//financeapi/cancelWith', {
						id: data.id
					}, function() {
						app.tips('操作成功');
						_this.load();
					});
				});
			},
			toInvoice:function(){
				let options = this.getData().options;
				app.navTo('../../finance/withdrawInvoice/withdrawInvoice?id='+options.id);
			},
		}
	});
})();