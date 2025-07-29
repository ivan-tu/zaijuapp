/**
 * Universal Links JavaScript处理器
 * 集成到在局App现有的桥接系统中
 */

// 等待wx.app初始化完成后添加处理器
(function() {
    'use strict';
    
    console.log('📱 [Universal Links] 处理器开始加载');
    
    // 检查wx.app是否存在，如果不存在则等待
    function waitForWxApp(callback) {
        if (typeof wx !== 'undefined' && wx.app && wx.app.on) {
            callback();
        } else {
            setTimeout(function() {
                waitForWxApp(callback);
            }, 100);
        }
    }
    
    // 初始化Universal Links处理器
    function initUniversalLinksHandler() {
        console.log('📱 [Universal Links] 初始化处理器');
        
        // 添加到wx.app.on处理器中
        wx.app.on.handleUniversalLinkNavigation = function(data, responseCallback) {
            console.log('📱 [Universal Links] 收到路由请求:', data);
            
            try {
                if (!data || !data.path) {
                    console.warn('⚠️ [Universal Links] 路径数据无效');
                    app.trigger(responseCallback, {
                        success: false,
                        errorMessage: '路径数据无效'
                    });
                    return;
                }
                
                const path = data.path;
                const timestamp = data.timestamp;
                
                console.log(`🧭 [Universal Links] 处理路径: ${path}, 时间戳: ${timestamp}`);
                
                // 解析路径
                const url = new URL('https://zaiju.com' + path);
                const pathParts = url.pathname.split('/').filter(part => part); // 移除空字符串
                const searchParams = new URLSearchParams(url.search);
                
                // 移除 'app' 前缀
                if (pathParts[0] === 'app') {
                    pathParts.shift();
                }
                
                console.log('📍 [Universal Links] 解析结果:', {
                    pathParts: pathParts,
                    searchParams: Object.fromEntries(searchParams)
                });
                
                // 执行路由处理
                const handled = handleUniversalLinkRoute(pathParts, searchParams);
                
                // 返回处理结果
                app.trigger(responseCallback, {
                    success: handled,
                    data: {
                        path: path,
                        handled: handled
                    },
                    errorMessage: handled ? '' : '路由处理失败'
                });
                
            } catch (error) {
                console.error('❌ [Universal Links] 处理异常:', error);
                app.trigger(responseCallback, {
                    success: false,
                    errorMessage: error.message
                });
            }
        };
        
        console.log('✅ [Universal Links] 处理器注册完成');
    }
    
    /**
     * 处理Universal Link路由
     * @param {Array} pathParts 路径部分数组
     * @param {URLSearchParams} searchParams 查询参数
     * @returns {boolean} 是否成功处理
     */
    function handleUniversalLinkRoute(pathParts, searchParams) {
        if (pathParts.length === 0) {
            // 根路径，跳转到首页
            console.log('🏠 [Universal Links] 跳转到首页');
            return navigateToHome();
        }
        
        const mainPath = pathParts[0];
        
        switch (mainPath) {
            case 'user':
                return handleUserRoute(pathParts, searchParams);
            case 'circle':
                return handleCircleRoute(pathParts, searchParams);
            case 'share':
                return handleShareRoute(pathParts, searchParams);
            case 'post':
                return handlePostRoute(pathParts, searchParams);
            case 'home':
            case 'index':
                return navigateToHome();
            default:
                console.warn(`⚠️ [Universal Links] 未知路径类型: ${mainPath}`);
                // 回退到首页
                return navigateToHome();
        }
    }
    
    /**
     * 处理用户相关路由
     * 例如: /app/user/123 或 /app/user/profile
     */
    function handleUserRoute(pathParts, searchParams) {
        if (pathParts.length < 2) {
            console.warn('⚠️ [Universal Links] 用户路径不完整');
            return false;
        }
        
        const userAction = pathParts[1];
        
        if (userAction === 'profile') {
            // 跳转到个人资料页面
            console.log('👤 [Universal Links] 跳转到个人资料页面');
            return navigateToUserProfile();
        } else if (/^\d+$/.test(userAction)) {
            // 数字ID，跳转到用户详情页面
            const userId = userAction;
            console.log(`👤 [Universal Links] 跳转到用户详情页面: ${userId}`);
            return navigateToUserDetail(userId, Object.fromEntries(searchParams));
        } else {
            console.warn(`⚠️ [Universal Links] 未知用户路径: ${userAction}`);
            return false;
        }
    }
    
    /**
     * 处理圈子相关路由
     * 例如: /app/circle/456?tab=posts
     */
    function handleCircleRoute(pathParts, searchParams) {
        if (pathParts.length < 2) {
            console.warn('⚠️ [Universal Links] 圈子路径不完整');
            return false;
        }
        
        const circleId = pathParts[1];
        const tab = searchParams.get('tab') || 'home';
        
        console.log(`🔵 [Universal Links] 跳转到圈子: ${circleId}, 标签: ${tab}`);
        
        return navigateToCircle(circleId, { tab: tab });
    }
    
    /**
     * 处理分享相关路由
     * 例如: /app/share/post/789
     */
    function handleShareRoute(pathParts, searchParams) {
        if (pathParts.length < 3) {
            console.warn('⚠️ [Universal Links] 分享路径不完整');
            return false;
        }
        
        const shareType = pathParts[1]; // post, circle, user等
        const shareId = pathParts[2];
        
        console.log(`📤 [Universal Links] 处理分享: ${shareType} - ${shareId}`);
        
        switch (shareType) {
            case 'post':
                return navigateToPost(shareId, Object.fromEntries(searchParams));
            case 'circle':
                return navigateToCircle(shareId, Object.fromEntries(searchParams));
            case 'user':
                return navigateToUserDetail(shareId, Object.fromEntries(searchParams));
            default:
                console.warn(`⚠️ [Universal Links] 未知分享类型: ${shareType}`);
                return false;
        }
    }
    
    /**
     * 处理帖子相关路由
     * 例如: /app/post/123
     */
    function handlePostRoute(pathParts, searchParams) {
        if (pathParts.length < 2) {
            console.warn('⚠️ [Universal Links] 帖子路径不完整');
            return false;
        }
        
        const postId = pathParts[1];
        console.log(`📝 [Universal Links] 跳转到帖子: ${postId}`);
        
        return navigateToPost(postId, Object.fromEntries(searchParams));
    }
    
    // ========== 导航函数实现 ==========
    
    /**
     * 跳转到首页
     */
    function navigateToHome() {
        console.log('🏠 [Universal Links] 执行跳转到首页');
        try {
            // 方法1: 使用app原生方法切换到首页Tab
            if (typeof switchTab === 'function') {
                switchTab(0); // 假设首页是第0个tab
                return true;
            }
            
            // 方法2: 使用页面跳转
            if (typeof app !== 'undefined' && app.navigateTo) {
                app.navigateTo({
                    url: 'home/index'
                });
                return true;
            }
            
            // 方法3: 触发首页显示事件
            if (typeof wx !== 'undefined' && wx.app && wx.app.call) {
                wx.app.call('navigateTo', {
                    data: { url: 'home/index' }
                });
                return true;
            }
            
            console.warn('⚠️ [Universal Links] 无法找到首页跳转方法');
            return false;
        } catch (error) {
            console.error('❌ [Universal Links] 首页跳转失败:', error);
            return false;
        }
    }
    
    /**
     * 跳转到个人资料页面
     */
    function navigateToUserProfile() {
        console.log('👤 [Universal Links] 执行跳转到个人资料页面');
        try {
            // 根据app的路由规则调整
            if (typeof app !== 'undefined' && app.navigateTo) {
                app.navigateTo({
                    url: 'user/profile'
                });
                return true;
            }
            
            if (typeof wx !== 'undefined' && wx.app && wx.app.call) {
                wx.app.call('navigateTo', {
                    data: { url: 'user/profile' }
                });
                return true;
            }
            
            return false;
        } catch (error) {
            console.error('❌ [Universal Links] 个人资料页面跳转失败:', error);
            return false;
        }
    }
    
    /**
     * 跳转到用户详情页面
     */
    function navigateToUserDetail(userId, params) {
        console.log(`👤 [Universal Links] 执行跳转到用户详情: ${userId}`, params);
        try {
            const url = `user/detail?id=${userId}`;
            
            if (typeof app !== 'undefined' && app.navigateTo) {
                app.navigateTo({
                    url: url
                });
                return true;
            }
            
            if (typeof wx !== 'undefined' && wx.app && wx.app.call) {
                wx.app.call('navigateTo', {
                    data: { url: url }
                });
                return true;
            }
            
            return false;
        } catch (error) {
            console.error('❌ [Universal Links] 用户详情页面跳转失败:', error);
            return false;
        }
    }
    
    /**
     * 跳转到圈子页面
     */
    function navigateToCircle(circleId, params) {
        console.log(`🔵 [Universal Links] 执行跳转到圈子: ${circleId}`, params);
        try {
            let url = `circle/detail?id=${circleId}`;
            if (params && params.tab) {
                url += `&tab=${params.tab}`;
            }
            
            if (typeof app !== 'undefined' && app.navigateTo) {
                app.navigateTo({
                    url: url
                });
                return true;
            }
            
            if (typeof wx !== 'undefined' && wx.app && wx.app.call) {
                wx.app.call('navigateTo', {
                    data: { url: url }
                });
                return true;
            }
            
            return false;
        } catch (error) {
            console.error('❌ [Universal Links] 圈子页面跳转失败:', error);
            return false;
        }
    }
    
    /**
     * 跳转到帖子页面
     */
    function navigateToPost(postId, params) {
        console.log(`📝 [Universal Links] 执行跳转到帖子: ${postId}`, params);
        try {
            const url = `post/detail?id=${postId}`;
            
            if (typeof app !== 'undefined' && app.navigateTo) {
                app.navigateTo({
                    url: url
                });
                return true;
            }
            
            if (typeof wx !== 'undefined' && wx.app && wx.app.call) {
                wx.app.call('navigateTo', {
                    data: { url: url }
                });
                return true;
            }
            
            return false;
        } catch (error) {
            console.error('❌ [Universal Links] 帖子页面跳转失败:', error);
            return false;
        }
    }
    
    // 等待wx.app初始化后注册处理器
    waitForWxApp(function() {
        initUniversalLinksHandler();
    });
    
    console.log('📱 [Universal Links] 处理器文件加载完成');
})();