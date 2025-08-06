/**
 *模块组件构造器
 */
(function() {

	let app = getApp();

	app.Page({
		pageId: 'finance-withdraw',
		data: {
			systemId: 'finance',
			moduleId: 'withdraw',
			isUserLogin: app.checkUser(),
			data: {},
			options: {},
			settings: {},
			language: {},
			client: app.config.client,
			form: {
				total:0,
				pic:'',
			},
			canWithdraw:0,//可提现金额
			minWidthdraw:0,//最低可提现金额
			freezeWithdraw:0,//待结算金额
			withdrawInfo:{
				real_name: '',
				id_card: '',
				alipay_account: '',//支付宝
				bankname:'',//开户行
				bankcard:'',//银行卡号
			},//提现方式
			tipText:[],
			poundage:0,//税费百分比
			poundageTotal:0,//需要扣除的税费
			agreeMement:true,
			type:'',//user,club,shop,cityoffice
			picWidth:(app.system.windowWidth>480?480:app.system.windowWidth)-80,
			picHeight:((app.system.windowWidth>480?480:app.system.windowWidth)-80)/1.6,
			showFaPiao:false,//是否需要发票
		},
		methods: {
			onLoad: function(options) {
				let _this = this;
				_this.setData({
					options: options,
					type:options.type,
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
			screenAgree:function(){
				this.setData({agreeMement:!this.getData().agreeMement});
			},
			toRecord:function(){
				let options = this.getData().options;
				if(options.subofficeid){
					app.navTo('../../finance/withdrawList/withdrawList?subofficeid='+options.subofficeid+'&type='+options.type);
				}else if(options.clubid){
					app.navTo('../../finance/withdrawList/withdrawList?clubid='+options.clubid+'&type='+options.type);
				}else if(options.shopid){
					app.navTo('../../finance/withdrawList/withdrawList?shopid='+options.shopid+'&type='+options.type);
				}else{
					app.navTo('../../finance/withdrawList/withdrawList?&type='+options.type);
				};
			},
			toWithdrawSet:function(){
				let options = this.getData().options;
				if(options.subofficeid){
					app.navTo('../../finance/withdrawSet/withdrawSet?subofficeid='+options.subofficeid+'&type='+options.type);
				}else if(options.clubid){
					app.navTo('../../finance/withdrawSet/withdrawSet?clubid='+options.clubid+'&type='+options.type);
				}else if(options.shopid){
					app.navTo('../../finance/withdrawSet/withdrawSet?shopid='+options.shopid+'&type='+options.type);
				}else{
					app.navTo('../../finance/withdrawSet/withdrawSet?&type='+options.type);
				};
			},
			load: function() {
				let _this = this,
					options = this.getData().options,
					type = this.getData().type,
					requestData = {
						type:type
					};
				if(options.shopid){
					requestData.shopid = options.shopid;
				}else if(options.clubid){
					requestData.clubid = options.clubid;
				}else if(options.subofficeid){
					requestData.subofficeid = options.subofficeid;
				};
				//获取可提现金额
				app.request('//financeapi/getUserFinance',requestData,function(res) {
					_this.setData({
						canWithdraw:res.balance||0
					});
					if(res.poundage&&res.poundage>0){
						_this.setData({
							poundage:Number(app.getPrice(res.poundage))
						});
					};
					if(res.tips){
						_this.setData({
							tipText:[res.tips]
						});
					};
					if(res.minwith){//最低可提现
						_this.setData({
							minWidthdraw:res.minwith
						});
					};
				});
				//获取提现方式
				app.request('//financeapi/getAlipayAccount',requestData, function(res) {
					if (res) {
						_this.setData({
							'withdrawInfo.real_name':res.real_name||'',
							'withdrawInfo.id_card':res.id_card||'',
							'withdrawInfo.bankcard':res.bankcard||'',
						});
						if(res.type=='clubdiamond'&&res.banktype=='company'){
							_this.setData({
								showFaPiao:true
							});
						};
					};
				});
			},
			getAll: function() {
				let canWithdraw = this.getData().canWithdraw;
				this.setData({
					'form.total': canWithdraw
				});
				//this.getPoundageTotal();
			},
			submit: function() {
				let _this = this,
					options = this.getData().options,
					form = this.getData().form,
					type = this.getData().type,
					agreeMement = this.getData().agreeMement,
					isPrice =  /^[1-9]\d*$/,
					withdrawInfo = this.getData().withdrawInfo,
					canWithdraw = Number(this.getData().canWithdraw),
					minWidthdraw = Number(this.getData().minWidthdraw),
					showFaPiao = this.getData().showFaPiao,
					msg = '';
				if(options.clubdiamond==1){
					form.type = 'clubdiamond';
				}else{
					form.type = type;
				};
				if(options.shopid){
					form.shopid = options.shopid;
				}else if(options.clubid){
					form.clubid = options.clubid;
				}else if(options.subofficeid){
					form.subofficeid = options.subofficeid;
				};
				if(!_this.stopIng){
					_this.stopIng = true;
					form.total = Number(form.total);
					if (!withdrawInfo.bankcard) {
						msg = '请先设置提现帐号';
					}else if (form.total < minWidthdraw) {
						msg = '最低提现' + minWidthdraw + '元';
					}else if (form.total > canWithdraw) {
						msg = '余额不足，最多提现' + canWithdraw + '元';
					}else if (showFaPiao&&!form.pic) {
						msg = '请上传发票照片';
					};
					if(msg){
						app.tips(msg,'error');
						_this.stopIng = false;
					}else{
						app.request('//financeapi/applyWith', form, function(res) {
							app.tips('提现申请成功');
							_this.setData({
								'form.total':'',
								'form.pic':''
							});
							if(showFaPiao){
								_this.selectComponent('#uploadPic').reset();
							};
							setTimeout(function(){
								app.navTo('../../finance/withdrawDetail/withdrawDetail?ordernum=' + res.ordernum);
							},600);
						},'',function(){
							_this.stopIng = false;
						});
					};
				}else{
					app.tips('请勿重复点击','error');
				};
			},
			uploadSuccess: function(e) {
				this.setData({
					'form.pic': e.detail.src[0]
				});
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