(function() {

	let app = getApp();

	app.Page({
		pageId: 'suboffice-officeWallteRecord',
		data: {
			systemId: 'suboffice',
			moduleId: 'officeWallteRecord',
			isUserLogin: app.checkUser(),
			data: [],
			options: {},
			settings: {
				bottomLoad: false
			},
			language: {},
			form: {
				page:1,
				size:30,
				clubid:'',
				timestap:'',
				begindate:'',
				enddate:'',
			},
			begindate:app.getNowDate(),
			enddate:app.getNowDate(),
			showDate:false,
			showLoading:false,
			showNoData:false,
			count:0,
			pageCount:0,
			total:0,
		},
		methods: {
			onLoad: function(options) {
				let _this = this;
				this.setData({
					form:app.extend(this.getData().form,options)
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
				this.setData({
					'form.page': 1
				});
				if (this.getData().isUserLogin) {
					this.load();
				};
				wx.stopPullDownRefresh();
			},
			load: function() {
				this.getList();
			},
			screenType:function(e){
				let type = app.eData(e).type,
					formData = this.getData().form;
				if(type=='showDate'){
					this.setData({
						'form.timestap':'',
						showDate:true
					});
				}else{
					this.setData({
						'form.timestap':type,
						'form.begindate':'',
						'form.enddate':'',
						'form.page':1,
						showDate:false
					});
					this.getList();
				};
			},
			bindStartTime: function (e) {
				this.setData({
					'form.begindate': e.detail.value,
					begindate: e.detail.value,
				});
			},
			bindEndTime: function (e) {
				this.setData({
					'form.enddate': e.detail.value,
					enddate: e.detail.value,
				});
			},
			confirmTime: function () {
				let _this = this,
					formData = _this.getData().form,
					begindate = formData.begindate ? Date.parse(new Date(formData.begindate)) : '',
					enddate = formData.enddate ? Date.parse(new Date(formData.enddate)) : '';
				if (begindate && enddate && begindate > enddate) {
					app.tips('结束时间不能小于起始时间', 'error');
					_this.setData({
						'form.enddate': ''
					});
				} else {
					_this.setData({'form.page':1});
					_this.getList();
				};
			},
			getList:function(loadMore){
				let _this = this,
					formData = _this.getData().form,
					pageCount = _this.getData().pageCount;
				if(loadMore){
					if (formData.page >= pageCount) {
						_this.setData({'settings.bottomLoad':false});
					};
				};
				_this.setData({'showLoading':true});
				app.request('//clubapi/getClubBeansLog',formData,function(backData){
					if(!backData||!backData.data){
						backData = {data:[],count:0};
					};
					if(!loadMore){
						if(backData.count){
							pageCount = Math.ceil(backData.count / formData.size);
							_this.setData({'pageCount':pageCount});
							if(pageCount > 1){
								_this.setData({'settings.bottomLoad':true});
							}else{
								_this.setData({'settings.bottomLoad':false});
							};
							_this.setData({'showNoData':false});
						}else{
							_this.setData({
								'settings.bottomLoad':false,
								'showNoData':true
							});
						};
					};
					let list = backData.data;
					if(list&&list.length){
						app.each(list,function(i,item){
							item.list = [];
							item.show = 0;
						});
					};
					if(loadMore){
						list = _this.getData().data.concat(list);
					};
					_this.setData({
						data:list,
						count:backData.count||0,
						total:backData.total||0,
					});
				},'',function(){
					_this.setData({
						'showLoading':false,
					});
				});
			},
			onReachBottom:function(){
				if(this.getData().settings.bottomLoad) {
					let formData = this.getData().form;
					formData.page++;
					this.setData({form:formData});
					this.getList(true);
				};
			},
			getThisDetail:function(e){
				let _this = this,
					index = Number(app.eData(e).index),
					data = this.getData().data,
					formData = this.getData().form,
					url = app.mixURL('../../usefulShop/client_myAchievementRecord/client_myAchievementRecord',{
						fromre:formData.fromre,
						type:formData.type,
						status:formData.status,
						adddate:data[index].date,
						gettype:formData.gettype,
					});
				app.navTo(url);
			},
		}
	});
})();