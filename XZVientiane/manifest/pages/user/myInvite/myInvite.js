/**
 *模块组件构造器
 */
(function() {

    let app = getApp();

    app.Page({
        pageId: 'user-myInvite',
        data: {
            systemId: 'user',
            moduleId: 'myInvite',
            data: [],
            options: {},
            settings: {
				bottomLoad:false,
			},
            form: {
				page:1,
				size:10,
				keyword:'',
				isexpert:'',
				isagent:'',
				ispartner:'',
			},
			client:app.config.client,
			showLoading:false,
			showNoData:false,
			count:0,
			pageCount:0,
			picWidth:((app.system.windowWidth>480?480:app.system.windowWidth)-40)*0.5,
			picHeight:((app.system.windowWidth>480?480:app.system.windowWidth)-40)*0.5/0.875,
			checkParentDialog:{
				show:false,
				height:260,
				parentData:{},
				account:'',
				id:'',
				index:'',
			},
        },
        methods: {
            onLoad: function(options) {
				let _this = this;
				_this.setData({
					options: options,
					form:app.extend(this.getData().form,options)
				});
				app.checkUser({
					goLogin: false,
					success: function () {
						_this.setData({
							isUserLogin: true
						});
					}
				});
				this.load();
            },
            onPullDownRefresh: function() {
                this.load();
                wx.stopPullDownRefresh();
            },
            load: function() {
				this.getList();
            },
			changeKeyword: function(e) {
				let keyword = e.detail.keyword;
				this.setData({
					'form.keyword': e.detail.keyword,
					'form.page': 1
				});
				this.getList();
			},
			closeKeyword: function(e) {
				let keyword = e.detail.keyword;
				this.setData({
					'form.keyword': '',
					'form.page': 1
				});
				this.getList();
			},
			screen:function(e){
				let formData = this.getData().form,
					type = app.eData(e).type,
					value = app.eData(e).value;
				formData[type] = value;
				formData.page = 1;
				this.setData({form:formData});
				this.getList();
			},
			screenType:function(e){
				let formData = this.getData().form,
					type = app.eData(e).type;
				switch(type){
					case 'all':
					formData.isexpert = '';
					formData.isagent = '';
					formData.ispartner = '';
					break;
					case 'isexpert':
					formData.isexpert = '1';
					formData.isagent = '';
					formData.ispartner = '';
					break;
					case 'isagent':
					formData.isexpert = '';
					formData.isagent = '1';
					formData.ispartner = '';
					break;
					case 'ispartner':
					formData.isexpert = '';
					formData.isagent = '';
					formData.ispartner = '1';
					break;
					case 'other':
					formData.isexpert = '0';
					formData.isagent = '';
					formData.ispartner = '';
					break;
				};
				formData.page = 1;
				this.setData({form:formData});
				this.getList();
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
				app.request('//homeapi/getMyTeamList',formData,function(backData){
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
							item.id = item.id||item._id;
							if(item.headpic){
								item.headpic = app.image.crop(item.headpic,70,70);
							};
						});
					};
					if(loadMore){
						list = _this.getData().data.concat(list);
					};
					_this.setData({
						data:list,
						count:backData.count||0,
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
			toDetail:function(e){
				let _this = this,
					id = app.eData(e).id;
				app.actionSheet(['查看名片','转让他人'],function(res){
					switch(res){
						case 0:
						app.navTo('../../user/businessCard/businessCard?id='+id);
						break;
						case 1:
						_this.setData({
							'checkParentDialog.id':id,
							'checkParentDialog.show':true,
							'checkParentDialog.account':'',
							'checkParentDialog.parentData':{},
						});
						break;
					};
				});
			},
			toHideCheckDialog:function(){
				this.setData({
					'checkParentDialog.show':false,
				});
			},
			toEditParent:function(){
				this.setData({
					'checkParentDialog.parentData':'',
					'checkParentDialog.account':'',
				});
			},
			checkAccount:function(){//检测账号
				let _this = this,
					checkParentDialog = this.getData().checkParentDialog;
				if(!checkParentDialog.account){
					app.tips('请输入手机号码','error');
				}else{
					app.request('//userapi/getInfoByAccount',{account:checkParentDialog.account},function(res){
						if(res&&res.invitationNum){
							res.headpic = app.image.crop(res.headpic,60,60);
							res.account = checkParentDialog.account;
							_this.setData({
								'checkParentDialog.parentData':res,
								'checkParentDialog.edit':1
							});
						}else{
							app.tips('用户不存在','error');
						};
					});
				};
			},
			toConfirmCheckDialog:function(){
				let _this = this,
					checkParentDialog = this.getData().checkParentDialog,
					msg = '';
				if(!checkParentDialog.parentData||!checkParentDialog.parentData.invitationNum){
					msg = '请确认推荐人';
				};
				if(msg){
					app.tips(msg,'error');
				}else{
					_this.toHideCheckDialog();
					app.request('//userapi/trunUserParent',{userid:checkParentDialog.id,touserid:checkParentDialog.parentData._id},function(){
						_this.toHideCheckDialog();
						app.tips('转让成功','success');
						_this.load();
					});
				};
			},
        }
    });
})();