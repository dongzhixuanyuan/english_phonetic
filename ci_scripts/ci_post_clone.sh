#!/bin/sh

# 安装 CocoaPods 依赖
cd "$CI_PRIMARY_REPOSITORY_PATH/ios" || exit 1
pod install
