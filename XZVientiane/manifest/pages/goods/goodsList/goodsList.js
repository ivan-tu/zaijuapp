/**
 *模块组件构造器
 */
(function () {

	let app = getApp();

	app.Page({
		pageId: 'goods-goodsList',
		data: {
			systemId: 'goods',
			moduleId: 'goodsList',
			isUserLogin: app.checkUser(),
			data: [],
			options: {},
			settings: {
				bottomLoad: true,
				noMore: false,
			},
			language: {},
			form: {
				page: 1,
				size: 10,
				status: '1',
				goodsCategoryId: '', //自定义分类
				sort: 'top',
				keyword: '',
				goodsTypeid: '', //系统分类id
				diamondpay:1,
			},
			client: app.config.client,
			showLoading: false,
			showNoData: false,
			pageCount: 0,
			count: 0,
			categoryData: [],
			visitShopShortId: '',
			showDialog: false,
			showDialog_animate: false,
			selectedIndex: 0,
			selectedCount: 1,
			detailData: {
				sku: []
			}, //详情数据
			showType: 'top',
			goodsPicWidth:((app.system.windowWidth>480?480:app.system.windowWidth)-30)/2,
			goodsPicHeight:((app.system.windowWidth>480?480:app.system.windowWidth)-30)/2,
		},
		methods: {
			onLoad: function (options) {
				let _this = this,
					opts = {};
				if(options.title){
					app.setPageTitle(options.title);
					delete options.title;
				};
				_this.setData({
					form: app.extend(_this.getData().form, options)
				});
				_this.load();
			},
			onShow: function () {
				//检查用户登录状态
				let isUserLogin = app.checkUser();
				if (isUserLogin != this.getData().isUserLogin) {
					this.setData({
						isUserLogin: isUserLogin
					});
					this.load();
				};
			},
			onPullDownRefresh: function () {
				this.setData({
					'form.page': 1
				});
				if (this.getData().isUserLogin) {
					this.load();
				};
				wx.stopPullDownRefresh();
			},
			load: function () {
				this.getList();
			},
			screenType: function (e) {
				this.setData({
					'form.page': 1,
					'form.goodsCategoryId': app.eData(e).id,
					'settings.bottomLoad': true
				});
				this.getList();
			},
			changeKeyword: function (e) {
				//document.activeElement.blur();
				let keyword = e.detail.keyword;
				this.setData({
					'form.keyword': e.detail.keyword,
					'form.page': 1
				});
				this.getList();
			},
			closeKeyword: function (e) {
				let keyword = e.detail.keyword;
				this.setData({
					'form.keyword': '',
					'form.page': 1
				});
				this.getList();
			},
			getList: function (loadMore) {
				let _this = this,
					formData = _this.getData().form,
					pageCount = _this.getData().pageCount;
				_this.setData({
					'showLoading': true
				});
				if (loadMore) {
					if (formData.page >= pageCount) {
						_this.setData({
							'settings.bottomLoad': false,
							'settings.noMore': true
						});
					};
				} else {
					_this.setData({
						'settings.bottomLoad': true,
						'settings.noMore': false
					});
					if (_this.getData().data.length && formData.page > 1) {
						_this.defaultSize = formData.size;
						_this.defaultPage = formData.page;
						formData.size = formData.page * formData.size;
						formData.page = 1;
					};
				};
				app.request('//shopapi/getAllGoodsList', formData, function (backData) {
					if (!backData.data) {
						backData.data = [];
					};
					if (!loadMore) {
						if (backData.count) {
							pageCount = Math.ceil(backData.count / formData.size);
							_this.setData({
								pageCount: pageCount
							});
							if (pageCount == 1) {
								_this.setData({
									'settings.bottomLoad': false
								});
							};
							_this.setData({
								'showNoData': false
							});
						} else {
							_this.setData({
								'showNoData': true
							});
						};
					};
					let list = backData.data;
					if (list && list.length) {
						app.each(list, function (i, item) {
							item.id = item.id || item._id;
							if (item.pic) {
								item.pic = app.image.crop(item.pic, _this.getData().goodsPicWidth, _this.getData().goodsPicHeight);
							};
						});
					};
					if (loadMore) {
						list = _this.getData().data.concat(backData.data);
					} else {
						if (_this.defaultSize) {
							formData.page = _this.defaultPage;
							formData.size = _this.defaultSize;
							_this.defaultPage = null;
							_this.defaultSize = null;
						};
					};
					_this.setData({
						data: list,
						count: backData.count || 0
					});
				}, '', function () {
					_this.setData({
						'showLoading': false
					});
				});
			},

			loadMore: function () {
				let _this = this,
					form = this.getData().form;
				form.page++;
				this.setData({
					form: form
				});
				this.getList(true);
			},
			onReachBottom: function () {
				if (this.getData().settings.bottomLoad) {
					this.loadMore();
				};
			},
			//跳转详情
			toDetail: function (e) {
				app.navTo('../../shop/goodsDetail/goodsDetail?id=' + app.eData(e).id);
			},
			viewThisImage: function (e) {
				let _this = this,
					pic = app.eData(e).pic;
				pic = pic.split('?')[0];
				app.previewImage({
					current: pic,
					urls: [pic]
				})
			},
			toSearch: function () {
				this.setData({
					'form.page': 1
				});
				this.getList();
			},
			closeSearch: function () {
				this.setData({
					'form.page': 1,
					'form.keyword': ''
				});
				this.getList();
			},
			selectCateogry: function () {
				let _this = this,
					formData = this.getData().form;
				this.dialog({
					title: '选择分类',
					url: '../../manage/selectCategory/selectCategory?hasAll=1&id=' + formData.goodsTypeid,
					success: function (res) {
						console.log(app.toJSON(res));
						if (res.sId) {
							_this.setData({
								'form.goodsTypeid': res.sId
							});
							if(res.sTitle){
								setTimeout(function(){
									app.setPageTitle(res.sTitle);
								},400);
							};
						} else if (res.pId) {
							_this.setData({
								'form.goodsTypeid': res.pId
							});
							if(res.pTitle){
								setTimeout(function(){
									app.setPageTitle(res.pTitle);
								},400);
							};
						} else {
							_this.setData({
								'form.goodsTypeid': ''
							});
							setTimeout(function(){
								app.setPageTitle('商品');
							},400);
						};
						_this.getList();
					}
				});
			},
		}
	});
})();