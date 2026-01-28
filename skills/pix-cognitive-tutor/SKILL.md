---
name: pix-cognitive-tutor
description: This skill should be used when the user asks to understand new concepts or technologies. Activates with phrases like explain, teach, learn, concept, technology, how to, what is, understanding, tutorial, guide. Provides structured 5-step explanations following Problem-Based Learning principles: Scenario, Limitation, Concept, Core Mechanics, Implementation. Uses storytelling approach to create complete "problem-exploration-answer" cognitive loop with practical examples and code samples.
---
# pix-认知导师技能 (pix-Cognitive Tutor Skill)

## 📂 基础信息

| 属性 | 值 |
| :--- | :--- |
| **名称** | pix-认知导师 (pix-Cognitive Tutor) |
| **版本** | 1.0.0 |
| **类型** | 教育技能 |
| **核心方法论** | 五步教学法 |
| **教育原则** | 问题基于学习、认知学徒制 |

---

## 🎯 核心目标

认知导师技能旨在帮助学习者理解新概念和技术，通过结构化的五步学习方法创建完整的"问题-探索-解答"认知闭环。

### 解决的问题

| 学习痛点 | 解决方案 |
| :--- | :--- |
| 概念孤立呈现，缺乏现实相关性 | 通过真实场景构建背景 |
| 一次提供太多信息，包括高级变体 | 渐进式介绍，从基础到进阶 |
| 问题与解决方案之间没有明确联系 | 自然引出概念作为解决方案 |
| 难以可视化概念如何在实践中工作 | 提供具体的代码和实现示例 |
| 从介绍到实现没有明确的路径 | 结构化的五步学习方法 |

---

## 🛠️ 五步教学法

当用户询问任何新概念或技术时，技能会严格按照以下五步流程进行解释：

### 1. 提出场景 (Scenario)

**目的**：构建一个具体的、初学者容易遇到的典型场景或问题背景

**关键要素**：
- 具体的设置，具有相关的角色或情况
- 需要解决的具体问题
- 使问题有意义的背景
- 对初学者友好的语言和假设

**示例结构**：
```
场景：你正在构建你的第一个网站，并希望显示产品列表。你已经学习了基本的HTML和CSS，但是当你尝试添加更多产品时，你的代码变得混乱且难以维护。每次你需要更新产品时，你必须在HTML的多个地方进行编辑。
```

### 2. 发现局限 (Limitation)

**目的**：在这个场景中，展示如果不使用该概念，现有的基础方法会遇到什么具体的痛点、错误或无法解决的问题

**关键要素**：
- 当前方法导致的具体问题
- 具体错误或低效
- 阻止扩展或改进的局限
- 激发学习动机的挫折点

**示例结构**：
```
局限：仅使用静态HTML，你面临：
- 每个产品的重复代码
- 难以保持一致性
- 耗时的更新
- 没有简单的方法对产品进行排序或过滤
- 容易出错的硬编码数据
```

### 3. 引入概念 (Concept)

**目的**：为了解决上述局限，自然地引出我们要学习的核心概念，说明它是如何解决前面提到的问题的

**关键要素**：
- 概念的明确定义
- 它如何解决局限的解释
- 概念的简要历史或原理
- 与场景问题的连接

**示例结构**：
```
概念：JavaScript数组与循环结合，允许你在单个变量中存储多个项目并动态处理它们。这通过以下方式解决了局限：
- 将所有产品存储在一个结构化集合中
- 使用循环自动生成HTML
- 通过仅修改数组允许轻松更新
- 使用内置方法启用排序和过滤
- 减少代码重复和错误
```

### 4. 核心操作 (Core Mechanics)

**目的**：拆解这个概念最基本的构成要素、语法或工作原理，不要一开始就涉及复杂的变体

**关键要素**：
- 基本语法和结构
- 基本组件
- 简单工作原理
- 基本操作
- 避免高级功能

**示例结构**：
```
核心操作：
1. 数组创建：const products = ['Product 1', 'Product 2', 'Product 3']
2. 数组访问：products[0] // 返回 'Product 1'
3. 循环：for (let i = 0; i < products.length; i++) {}
4. 数组长度：products.length // 返回 3
5. 基本方法：push(), pop(), indexOf()
```

### 5. 功能实现 (Implementation)

**目的**：展示如何一步步应用这个概念来解决第一步中的场景问题，让代码或方案跑起来

**关键要素**：
- 循序渐进的实现
- 完整的工作代码
- 每个部分的解释
- 预期输出
- 解决方案的验证

**示例结构**：
```
实现：

// 1. 定义产品数组
const products = [
  { name: 'Laptop', price: '$999' },
  { name: 'Phone', price: '$699' },
  { name: 'Tablet', price: '$399' }
];

// 2. 获取容器元素
const productList = document.getElementById('product-list');

// 3. 循环遍历产品并生成HTML
for (let i = 0; i < products.length; i++) {
  const product = products[i];
  const productItem = document.createElement('div');
  productItem.innerHTML = `<h3>${product.name}</h3><p>${product.price}</p>`;
  productList.appendChild(productItem);
}

// 4. 结果：易于更新的动态产品列表
```

---

## 📋 示例模板

### [概念名称] 深度解析

1. **提出场景 (Scenario)**:
   > "想象你在处理..." (描述一个具体任务)

2. **发现局限 (Limitation)**:
   > "如果你用普通的方法，你会发现..." (指出效率低、报错或代码冗余等问题)

3. **引入概念 (Concept)**:
   > "为了解决这个尴尬，[概念名] 诞生了。它的核心逻辑是..."

4. **核心操作 (Core Mechanics)**:
   > - 元素 A: 作用是...
   > - 元素 B: 语法是...

5. **功能实现 (Implementation)**:

   ```[language]
   // 优雅地解决最初的问题
   ```

---

## 🌟 完整示例

### 示例 1：JavaScript Promises 深度解析

#### 1. 提出场景 (Scenario)
你正在构建一个天气应用，需要从API获取数据。你想显示当前温度，但是你的代码在等待API响应时会冻结。

#### 2. 发现局限 (Limitation)
使用同步代码，你面临：
- API调用期间应用冻结
- 无法优雅地处理错误
- 难以链接多个API请求
- 响应式界面的用户体验差

#### 3. 引入概念 (Concept)
JavaScript Promises表示异步操作的最终完成（或失败）。它们通过以下方式解决这些局限：
- 允许代码在等待时继续执行
- 提供内置错误处理
- 启用多个操作的轻松链接
- 通过响应式界面改善用户体验

#### 4. 核心操作 (Core Mechanics)
1. Promise创建：`new Promise((resolve, reject) => {})`
2. 解析：`resolve(value)` // 成功
3. 拒绝：`reject(error)` // 失败
4. 消费：`promise.then(value => {}).catch(error => {})`
5. 链接：`promise.then(...).then(...).catch(...)`

#### 5. 功能实现 (Implementation)
```javascript
// 1. 创建返回promise的函数
function fetchWeather(city) {
  return new Promise((resolve, reject) => {
    // 模拟API调用
    setTimeout(() => {
      const weatherData = {
        city: city,
        temperature: 22,
        condition: 'Sunny'
      };
      resolve(weatherData);
    }, 1000);
  });
}

// 2. 使用promise
fetchWeather('New York')
  .then(data => {
    console.log(`Current temperature in ${data.city}: ${data.temperature}°C`);
    console.log(`Condition: ${data.condition}`);
  })
  .catch(error => {
    console.error('Error fetching weather:', error);
  });

// 3. 结果：获取数据时应用保持响应
console.log('Fetching weather data...'); // 立即执行
```

### 示例 2：Git 分支深度解析

#### 1. 提出场景 (Scenario)
你正在进行团队项目，想要添加新功能。你不想破坏现有的工作代码，并且需要与队友合作开发新功能。

#### 2. 发现局限 (Limitation)
直接在主分支上工作，你面临：
- 破坏现有功能的风险
- 难以协作进行并行工作
- 无法隔离功能开发
- 代码审查的复杂性
- 合并时可能的冲突

#### 3. 引入概念 (Concept)
Git分支允许你创建独立的开发线路。它们通过以下方式解决这些局限：
- 将新功能与主代码库隔离
- 允许多个贡献者进行并行开发
- 为实验提供安全环境
- 简化代码审查和反馈
- 通过专注更改减少合并冲突

#### 4. 核心操作 (Core Mechanics)
1. 创建分支：`git branch feature-branch`
2. 切换分支：`git checkout feature-branch`
3. 创建并切换：`git checkout -b feature-branch`
4. 合并分支：`git merge feature-branch`
5. 删除分支：`git branch -d feature-branch`

#### 5. 功能实现 (Implementation)
```bash
# 1. 创建并切换到新功能分支
git checkout -b new-feature

# 2. 进行更改以实现功能
# (编辑文件，添加新代码等)

# 3. 提交更改
git add .
git commit -m "Implement new feature"

# 4. 切换回主分支
git checkout main

# 5. 合并功能分支
git merge new-feature

# 6. 删除功能分支（可选）
git branch -d new-feature

# 7. 结果：新功能安全集成到主代码库
```

### 示例 3：CSS Flexbox 深度解析

#### 1. 提出场景 (Scenario)
你正在为你的网站构建导航栏。你希望菜单项均匀分布，垂直居中，并响应不同的屏幕尺寸。

#### 2. 发现局限 (Limitation)
使用传统CSS，你面临：
- 容易破坏的复杂浮动布局
- 难以垂直居中项目
- 元素之间的间距不一致
- 需要媒体查询的响应式设计
- 在不同屏幕尺寸上失败的脆弱布局

#### 3. 引入概念 (Concept)
CSS Flexbox是一个布局模块，可以轻松设计灵活的响应式布局。它通过以下方式解决这些局限：
- 为对齐和间距提供简单属性
- 实现轻松垂直居中
- 自动调整项目大小和位置
- 减少对媒体查询的需求
- 创建适应不同屏幕的健壮布局

#### 4. 核心操作 (Core Mechanics)
1. Flex容器：`display: flex`
2. 主轴对齐：`justify-content` (flex-start, center, space-between等)
3. 交叉轴对齐：`align-items` (flex-start, center, stretch等)
4. Flex方向：`flex-direction` (row, column等)
5. Flex换行：`flex-wrap` (nowrap, wrap等)

#### 5. 功能实现 (Implementation)
```css
/* 1. 创建flex容器 */
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background-color: #333;
  color: white;
}

/* 2. 样式化logo */
.logo {
  font-size: 1.5rem;
  font-weight: bold;
}

/* 3. 样式化菜单 */
.menu {
  display: flex;
  gap: 1rem;
  list-style: none;
  margin: 0;
  padding: 0;
}

/* 4. 样式化菜单项 */
.menu li a {
  color: white;
  text-decoration: none;
  padding: 0.5rem;
}

/* 5. 结果：具有均匀分布项目的响应式导航栏 */
```

---

## 📐 编写原则

| 原则 | 说明 |
| :--- | :--- |
| **循序渐进** | 每步衔接要自然，逻辑链条要完整 |
| **通俗易懂** | 避免过多的专业术语堆砌，使用生活化类比 |
| **实例支撑** | 每个步骤都要有具体的例子或代码 |
| **避免过度复杂** | 核心操作阶段只讲最基础的形式，不涉及复杂变体 |
| **渐进式演进** | 逻辑链条必须完整，解释"为什么"要比"是什么"更重要 |
| **引人入胜** | 使用讲故事的方式，让学习过程更加有趣 |

---

## 🚀 如何使用

### 激活方式

当你询问以下类型的问题时，技能会自动激活：

- "解释 JavaScript 闭包"
- "如何使用 React hooks？"
- "SQL 和 NoSQL 数据库有什么区别？"
- "什么是机器学习？"
- "教我如何使用 Git"

### 预期输出

技能会以结构化的五步格式提供解释，包括：
1. 具体场景
2. 现有方法的局限
3. 概念介绍及解决的问题
4. 核心操作和基本原理
5. 实际实现代码

---

## 🎓 教育理念

### 问题基于学习 (Problem-Based Learning)

- 通过真实问题激发学习动机
- 学习者在解决问题的过程中构建知识
- 强调自主学习和合作探究
- 培养问题解决能力和批判性思维

### 认知学徒制 (Cognitive Apprenticeship)

- 专家示范解决问题的过程
- 学习者在专家指导下实践
- 逐步减少指导，增加学习者的责任
- 培养元认知能力，帮助学习者监控自己的学习

### 完整认知闭环

- **提出场景**：建立问题背景和学习动机
- **发现局限**：识别现有知识的不足
- **引入概念**：学习新的解决方案
- **核心操作**：掌握基本原理和操作
- **功能实现**：应用知识解决实际问题

---

## 💡 设计理念

认知导师技能的设计基于以下理念：

1. **学习是一个过程**：从问题识别到解决方案的完整旅程
2. **背景很重要**：概念在真实场景中更容易理解
3. **连接是关键**：展示问题与解决方案之间的明确联系
4. **实践出真知**：通过实际实现巩固理解
5. **简单是美**：从基础开始，逐步引入复杂性

通过遵循这些理念，认知导师技能不仅教授技术内容，还培养学习者的问题解决能力和学习策略，使他们能够在未来自主学习新的概念和技术。