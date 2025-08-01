//
//  EVNCustomSearchBar.m
//  MMB_SaaS
//
//  Created by developer on 2017/9/27.
//  Copyright © 2017年 仁伯安. All rights reserved.
//

#import "EVNCustomSearchBar.h"

@interface EVNCustomSearchBar()<UITextFieldDelegate>
{
    UIImageView *_iconImgV;
    UIImageView *_iconCenterImgV;
    EVNCustomSearchBarIconAlign _iconAlignTemp;
    UITextField *_textField;
}

@end

@implementation EVNCustomSearchBar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initView];
    }
    return self;
}

- (void)awakeFromNib{
    [super awakeFromNib];
    [self initView];
    [self sizeToFit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self sizeToFit];
    NSLog(@"在局_textField.width.frame=%@", NSStringFromCGRect(self.frame));
}

/**
 * 撑开view的布局
 @return CGSize
 */
- (CGSize)intrinsicContentSize
{
    return UILayoutFittingExpandedSize;
}

- (void)initView
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, 56);
    if (!_isHiddenCancelButton)
    {
        [self addSubview:self.cancelButton];
        self.cancelButton.hidden = YES;
    }

    [self addSubview:self.textField];

    //    self.backgroundColor = [UIColor colorWithRed:0.733 green:0.732 blue:0.756 alpha:1.000];

    [self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

/**
 * 右边取消按钮
 @return UIButton
 */
- (UIButton *)cancelButton
{
    if (!_cancelButton)
    {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cancelButton.frame = CGRectMake(self.frame.size.width-60, 7, 60,36);
        _cancelButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
        [_cancelButton addTarget:self action:@selector(cancelButtonTouched) forControlEvents:UIControlEventTouchUpInside];
        [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        [_cancelButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        _cancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    }
    return _cancelButton;
}

/**
 * 搜索框
 @return UITextField
 */
- (UITextField *)textField
{
    if (!_textField)
    {
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(7, 4, self.frame.size.width-7*2, 36)];
        _textField.delegate = self;
        _textField.borderStyle = UITextBorderStyleNone;
        _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _textField.returnKeyType = UIReturnKeySearch;
        _textField.enablesReturnKeyAutomatically = YES;
        _textField.font = [UIFont systemFontOfSize:14.0f];
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        [_textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _textField.borderStyle = UITextBorderStyleNone;
        _textField.layer.cornerRadius = 2.0f;
        _textField.layer.masksToBounds = YES;
        _textField.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:244.0/255.0 blue:244.0/255.0 alpha:1.0];
    }
    return _textField;
}

- (void)setIconAlign:(EVNCustomSearchBarIconAlign)iconAlign
{
    if(!_iconAlignTemp)
    {
        _iconAlignTemp = iconAlign;
    }
    _iconAlign = iconAlign;
    [self ajustIconWith:_iconAlign];
}

- (void)ajustIconWith:(EVNCustomSearchBarIconAlign)iconAlign
{
    if (_iconAlign == EVNCustomSearchBarIconAlignCenter && ([self.text isKindOfClass:[NSNull class]] || !self.text || [self.text isEqualToString:@""] || self.text.length == 0) && ![_textField isFirstResponder])
    {
        _iconCenterImgV.hidden = NO;
        _textField.frame = CGRectMake(7, 4, self.frame.size.width - 7*2, 36);
        _textField.textAlignment = NSTextAlignmentCenter;

        CGSize titleSize; // 输入的内容或者placeholder数据

        titleSize =  [self.placeholder?:@"" sizeWithAttributes: @{NSFontAttributeName:_textField.font}];

        NSLog(@"在局----%f", _textField.frame.size.width);
        CGFloat x = _textField.frame.size.width/2.f - titleSize.width/2.f - 36;
        if (!_iconCenterImgV)
        {
            _iconCenterImgV = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"EVNCustomSearchBar.bundle/EVNCustomSearchBar"]];
            _iconCenterImgV.contentMode = UIViewContentModeScaleAspectFit;
            [_textField addSubview:_iconCenterImgV];
        }

        //        [UIView animateWithDuration:1 animations:^{
        _iconCenterImgV.frame = CGRectMake(x > 0 ?x:0, 0, 36, 36);
        _iconCenterImgV.hidden = x > 0 ? NO : YES;
        _textField.leftView = x > 0 ? nil : _iconImgV;
        _textField.leftViewMode =  x > 0 ? UITextFieldViewModeNever : UITextFieldViewModeAlways;
        //        }];
    }
    else
    {
        _iconCenterImgV.hidden = YES;
        [UIView animateWithDuration:1 animations:^{
            self->_textField.textAlignment = NSTextAlignmentLeft;
            self->_iconImgV = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"EVNCustomSearchBar.bundle/EVNCustomSearchBar"]];
            self->_iconImgV.contentMode = UIViewContentModeScaleAspectFit;
            self->_textField.leftView = self->_iconImgV;
            self->_textField.leftViewMode =  UITextFieldViewModeAlways;
        }];
    }
}

- (NSString *)text
{
    return _textField.text;
}

- (void)setText:(NSString *)text
{
    _textField.text = text?:@"";
    [self setIconAlign:_iconAlign];
}

- (void)setTextFont:(UIFont *)textFont
{
    _textFont = textFont;
    [_textField setFont:_textFont];
}

- (void)setTextBorderStyle:(UITextBorderStyle)textBorderStyle
{
    _textBorderStyle = textBorderStyle;
    _textField.borderStyle = textBorderStyle;
}

- (void)setTextColor:(UIColor *)textColor
{
    _textColor = textColor;
    [_textField setTextColor:_textColor];
}

- (void)setIconImage:(UIImage *)iconImage
{
    _iconImage = iconImage;
    ((UIImageView*)_textField.leftView).image = _iconImage;
    _textField.leftViewMode =  UITextFieldViewModeAlways;
}

- (void)setPlaceholder:(NSString *)placeholder
{
    _placeholder = placeholder;
    _textField.placeholder = placeholder;
    _textField.contentMode = UIViewContentModeScaleAspectFit;
    if (self.placeholderColor)
    {
        [self setPlaceholderColor:_placeholderColor];
    }
    [self setIconAlign:_iconAlign];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    _backgroundImage = backgroundImage;
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType
{
    _keyboardType = keyboardType;
    _textField.keyboardType = _keyboardType;
}

- (void)setInputView:(UIView *)inputView
{
    _inputView = inputView;
    _textField.inputView = _inputView;
}

- (BOOL)isUserInteractionEnabled
{
    return YES;
}

- (void)setInputAccessoryView:(UIView *)inputAccessoryView
{
    _inputAccessoryView = inputAccessoryView;
    _textField.inputAccessoryView = _inputAccessoryView;
}

- (void)setTextFieldColor:(UIColor *)textFieldColor
{
    _textField.backgroundColor = textFieldColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
    _placeholderColor = placeholderColor;
    NSAssert(_placeholderColor, @"Please set placeholder before setting placeholdercolor");

    // 使用官方API设置placeholder颜色
    if ([self.placeholder isKindOfClass:[NSNull class]] || !self.placeholder || [self.placeholder isEqualToString:@""])
    {
        // placeholder为空，不设置
    }
    else
    {
        _textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:
                                            @{NSForegroundColorAttributeName:placeholderColor,
                                              NSFontAttributeName:_textField.font
                                              }];
    }
}

- (BOOL)isFirstResponder
{
    return [_textField isFirstResponder];
}

- (BOOL)resignFirstResponder
{
    return [_textField resignFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    return [_textField becomeFirstResponder];
}

- (void)cancelButtonTouched
{
    _textField.text = @"";
    [_textField resignFirstResponder];
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarCancelButtonClicked:)])
    {
        [self.delegate searchBarCancelButtonClicked:self];
    }
}

- (void)setAutoCapitalizationMode:(UITextAutocapitalizationType)type
{
    _textField.autocapitalizationType = type;
}

#pragma mark - textfield delegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarShouldBeginEditing:)])
    {
        return [self.delegate searchBarShouldBeginEditing:self];
    }
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if(_iconAlignTemp == EVNCustomSearchBarIconAlignCenter)
    {
        self.iconAlign = EVNCustomSearchBarIconAlignLeft;
    }
    if (!_isHiddenCancelButton)
    {
        [UIView animateWithDuration:0.1 animations:^{
            self->_cancelButton.hidden = NO;
            self->_textField.frame = CGRectMake(7, 4, self->_cancelButton.frame.origin.x - 7, 36);
            // _textField.transform = CGAffineTransformMakeTranslation(-_cancelButton.frame.size.width,0);
        }];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarTextDidBeginEditing:)])
    {
        [self.delegate searchBarTextDidBeginEditing:self];
    }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarShouldEndEditing:)])
    {
        return [self.delegate searchBarShouldEndEditing:self];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if(_iconAlignTemp == EVNCustomSearchBarIconAlignCenter)
    {
        self.iconAlign = EVNCustomSearchBarIconAlignCenter;
    }
    if (!_isHiddenCancelButton)
    {
        [UIView animateWithDuration:0.1 animations:^{
            self->_cancelButton.hidden = YES;
            self->_textField.frame = CGRectMake(7, 4, self.frame.size.width - 7*2, 36);
            // _textField.transform = CGAffineTransformMakeTranslation(-_cancelButton.frame.size.width,0);
        }];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarTextDidEndEditing:)])
    {
        [self.delegate searchBarTextDidEndEditing:self];
    }
}

- (void)textFieldDidChange:(UITextField *)textField
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBar:textDidChange:)])
    {
        [self.delegate searchBar:self textDidChange:textField.text];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBar:shouldChangeTextInRange:replacementText:)])
    {
        return [self.delegate searchBar:self shouldChangeTextInRange:range replacementText:string];
    }
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBar:textDidChange:)])
    {
        [self.delegate searchBar:self textDidChange:@""];
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [_textField resignFirstResponder];
    if (self.delegate && [self.delegate respondsToSelector:@selector(searchBarSearchButtonClicked:)])
    {
        [self.delegate searchBarSearchButtonClicked:self];
    }
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isEqual:self] && [keyPath isEqualToString:@"frame"])
    {
        // _textField.frame = CGRectMake(7, 7, self.frame.size.width - 7*2, 30);
        NSLog(@"在局----%f", self.frame.size.width);
        [self ajustIconWith:_iconAlign];
    }
}

- (void)dealloc
{
    NSLog(@"在局class: %@ function:%s", NSStringFromClass([self class]), __func__);
    [self removeObserver:self forKeyPath:@"frame"];
}

@end
