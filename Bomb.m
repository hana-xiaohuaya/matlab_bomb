function Bomb(n, mm)
close all;
if nargin ~= 2
    % 添加难度选择对话框
    [selection, ok] = listdlg('PromptString', '选择难度:', ...
                             'SelectionMode', 'single', ...
                             'ListString', {'初级 (9×9, 10雷)', '中级 (16×16, 40雷)', '高级 (25×18, 80雷)', '自定义'});
    
    if ~ok
        return; % 用户取消选择，直接退出
    end
    
    switch selection
        case 1 % 初级
            n = [9, 9];
            mm = 10;
        case 2 % 中级
            n = [16, 16];
            mm = 40;
        case 3 % 高级
            n = [25, 18];
            mm = 80;
        case 4 % 自定义
            prompt = {'行数:', '列数:', '雷数:'};
            dlgtitle = '自定义难度';
            dims = [1 35];
            definput = {'16', '16', '40'};
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            if isempty(answer)
                return; % 用户取消输入，直接退出
            end
            
            n = [str2double(answer{1}), str2double(answer{2})];
            mm = str2double(answer{3});
    end
end

% 验证输入参数
if mm + 1 > n(1) * n(2) || mm < 1 || any(n <= 1)
    errordlg('参数设置错误: 雷数过多或网格太小', '设置错误');
    return;
end

% 创建主窗口
f1 = figure('Name', '扫雷', 'NumberTitle', 'off', 'Color', [1,1,1], ...
    'Position', [100,50,900,600], 'WindowButtonDownFcn', @BDF, ...
    'WindowButtonMotionFcn', @BMF, 'WindowButtonUpFcn', @BUF, ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off');

% 计算合适的窗口大小
figWidth = max(600, n(1)*30 + 150);
figHeight = max(400, n(2)*30 + 100);
f1.Position(3:4) = [figWidth, figHeight];

% 创建游戏区域
ax = axes(f1, 'XTick', [], 'YTick', [], 'XColor', [1,1,1], 'YColor', ...
    [1,1,1], 'Color', [1,1,1], 'Position', [0.05, 0.1, 0.7, 0.85], ...
    'XTickLabel', [], 'YTickLabel', [], 'XLim', [0,n(1)+1], ...
    'YLim', [0,n(2)+1], 'DataAspectRatio', [1,1,1]);

% 创建信息面板
infoPanel = uipanel(f1, 'Title', '游戏信息', 'Position', [0.77, 0.1, 0.2, 0.85], ...
                   'BackgroundColor', [0.9, 0.9, 0.9], 'FontSize', 12);

% 剩余雷数显示
uicontrol(infoPanel, 'Style', 'text', 'String', '剩余雷数:', ...
          'Units', 'normalized', 'Position', [0.1, 0.85, 0.8, 0.08], ...
          'BackgroundColor', [0.9, 0.9, 0.9], 'FontSize', 12, 'HorizontalAlignment', 'left');
T = uicontrol(infoPanel, 'Style', 'text', 'BackgroundColor', [1,1,1], 'String', ...
    num2str(mm), 'Units', 'normalized', 'Position', [0.1, 0.75, 0.8, 0.08], ...
    'FontSize', 18, 'FontWeight', 'bold', 'ForegroundColor', [1,0,0]);

% 计时器显示
uicontrol(infoPanel, 'Style', 'text', 'String', '游戏时间:', ...
          'Units', 'normalized', 'Position', [0.1, 0.65, 0.8, 0.08], ...
          'BackgroundColor', [0.9, 0.9, 0.9], 'FontSize', 12, 'HorizontalAlignment', 'left');
timerDisplay = uicontrol(infoPanel, 'Style', 'text', 'BackgroundColor', [1,1,1], 'String', ...
    '0', 'Units', 'normalized', 'Position', [0.1, 0.55, 0.8, 0.08], ...
    'FontSize', 18, 'FontWeight', 'bold', 'ForegroundColor', [0,0,1]);

% 创建重新开始按钮
uicontrol(infoPanel, 'Style', 'pushbutton', 'String', '重新开始', ...
          'Units', 'normalized', 'Position', [0.1, 0.4, 0.8, 0.1], ...
          'FontSize', 12, 'Callback', @restartGame);

% 创建难度选择按钮
uicontrol(infoPanel, 'Style', 'pushbutton', 'String', '更改难度', ...
          'Units', 'normalized', 'Position', [0.1, 0.25, 0.8, 0.1], ...
          'FontSize', 12, 'Callback', @changeDifficulty);

hold on

% 初始化游戏网格
for i = n(1):-1:1
    for j = n(2):-1:1
        M(i,j) = patch(ax, [i,i+1,i+1,i]-0.5, [j,j,j+1,j+1]-0.5, ...
            [0.8,0.8,0.8], 'EdgeColor', [0.7,0.7,0.7]);
        F(i,j) = image(ax, [i-0.4,i+0.4], [j-0.4,j+0.4], []);
    end
end

% 游戏状态变量
xd = 1; yd = 1;
xm = 1; ym = 1;
xu = 1; yu = 1;
PC = [0.8,0.8,0.8]; % 最后颜色
CD = uint8([0,0,225; 2,129,2; 253,7,7; 20,20,158; ...
    128,1,1; 0,128,128; 10,10,10; 128,128,128]); % 数字颜色

MT = 0; Endbuttom = '';
gameActive = false; % 游戏是否激活
startTime = 0; % 游戏开始时间
timerObj = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
                'TimerFcn', @updateTimer, 'StartDelay', 1);

% 旗帜图像
FLAG = zeros(9,9,3,'uint8'); 
FLAG(:,:,1) = [204 204 204 204 204 204 204 204 204;
    204 0 0 0 0 0 0 0 204;
    204 204 0 0 0 0 0 204 204;
    204 204 204 204 0 204 204 204 204;
    204 204 204 204 255 204 204 204 204;
    204 204 255 255 255 204 204 204 204;
    204 204 204 255 255 204 204 204 204;
    204 204 204 204 255 204 204 204 204;
    204 204 204 204 204 204 204 204 204];
FLAG(:,:,2) = [204 204 204 204 204 204 204 204 204;
    204 0 0 0 0 0 0 0 204;
    204 204 0 0 0 0 0 204 204;
    204 204 204 204 0 204 204 204 204;
    204 204 204 204 0 204 204 204 204;
    204 204 0 0 0 204 204 204 204;
    204 204 204 0 0 204 204 204 204;
    204 204 204 204 0 204 204 204 204;
    204 204 204 204 204 204 204 204 204];
FLAG(:,:,3) = FLAG(:,:,2);

% 炸弹图像
BOMB = zeros(15,15,3,'uint8'); 
BOMB(:,:,1) = [
    255 255 255 255 255 255 255 255 255 255 255 255 255 255 255;
    255 255 255 255 255 255 255 0 255 255 255 255 255 255 255;
    255 255 255 255 255 255 255 0 255 255 255 255 255 255 255;
    255 255 255 0 255 0 0 0 0 0 255 0 255 255 255;
    255 255 255 255 0 0 0 0 0 0 0 255 255 255 255;
    255 255 255 0 0 0 0 0 0 0 0 0 255 255 255;
    255 255 255 0 0 0 0 0 0 0 0 0 255 255 255;
    255 0 0 0 0 0 0 0 0 0 0 0 0 0 255;
    255 255 255 0 0 255 255 0 0 0 0 0 255 255 255;
    255 255 255 0 0 255 255 0 0 0 0 0 255 255 255;
    255 255 255 255 0 0 0 0 0 0 0 255 255 255 255;
    255 255 255 0 255 0 0 0 0 0 255 0 255 255 255;
    255 255 255 255 255 255 255 0 255 255 255 255 255 255 255;
    255 255 255 255 255 255 255 0 255 255 255 255 255 255 255;
    255 255 255 255 255 255 255 255 255 255 255 255 255 255 255];
BOMB([9,10],[6,7],[2,3]) = 255;

% 游戏数据
MDATA = zeros(n,'logical'); % 是否已打开
BF = zeros(n,'logical'); % 已标记的雷
NClick = true; % 首次点击保护
BDATA = zeros(n); % 雷的位置
Ndata = zeros(n); % 地图信息
aa = 1; bb = 1;
cc = false;
dd = true;

% 鼠标按下回调
function BDF(~,~)
    m = get(ax,'CurrentPoint');
    xd = round(m(1,1));
    yd = round(m(1,2));
    MT = length(get(f1,'SelectionType'));
    
    % 高亮显示可点击区域
    if xd>=1 && xd<=n(1) && yd>=1 && yd<=n(2) && MDATA(xd,yd) &&...
            Ndata(xd,yd)>0 && (MT==6 || MT==3)
        [a,b] = specialgrid(xd,yd);
        C = zeros(n,'logical');
        C(a,b) = true;
        [aa,bb] = find(C & ~MDATA & ~BF);
        for ii = [aa,bb].'
            M(ii(1),ii(2)).FaceColor = [0.6,0.6,0.6];
        end
        cc = true;
    end
    
    % 首次点击初始化雷区
    if NClick && xd>=1 && xd<=n(1) && yd>=1 && yd<=n(2)
        % 确保第一次点击不会是雷
        Bset = randperm(n(1) * n(2) - 1, mm) + 1;
        Npoint = (yd - 1) * n(1) + xd;
        if ismember(Npoint, Bset)
            Bset(Bset <= Npoint) = Bset(Bset <= Npoint) - 1;
        end
        BDATA(Bset) = 1;
        Ndata = conv2(BDATA, [1,1,1;1,0,1;1,1,1], 'same');
        Ndata(BDATA == 1) = -1;
        NClick = false;
        
        % 开始计时
        startTime = tic;
        start(timerObj);
        gameActive = true;
    end
end

% 鼠标移动回调
function BMF(~,~)
    if dd
        M(xm,ym).FaceColor = PC;
        M(xm,ym).FaceAlpha = 1;
    end
    m = round(get(ax,'CurrentPoint'));
    if m(1) < 1 || m(1) > n(1) || m(3) < 1 || m(3) > n(2)
        dd = false;
    else
        dd = true;
        xm = m(1); ym = m(3);
        PC = M(xm,ym).FaceColor;
        M(xm,ym).FaceColor = [0.8,0.8,0.8];
        M(xm,ym).FaceAlpha = 0.5;
    end
end

% 鼠标释放回调
function BUF(~,~)
    if cc
        for ii = [aa,bb].'
            M(ii(1),ii(2)).FaceColor = [0.8,0.8,0.8];
        end
        cc = false;
    end
    
    m = get(ax,'CurrentPoint');
    xu = round(m(1,1));
    yu = round(m(1,2));
    
    if xd==xu && yd==yu && xu>=1 && yu>=1 && xu<=n(1) && yu<=n(2)
        if ~MDATA(xu,yu)
            if MT == 6 % 左键点击
                if ~BF(xu,yu)
                    if Ndata(xu,yu) == -1 % 点到雷
                        BF(xu,yu) = true;
                        M(xu,yu).FaceColor = [1,0,0];
                        PC = [1,0,0];
                        F(xu,yu).CData = BOMB;
                        T.String = num2str(str2double(T.String) - 1);
                        if gameActive
                            stop(timerObj);
                            gameActive = false;
                            ENDq(false);
                        end
                    else % 安全区域
                        MDATA(xu,yu) = true;
                        M(xu,yu).FaceColor = [1,1,1];
                        PC = [1,1,1];
                        if Ndata(xu,yu) == 0
                            swap(xu,yu);
                        else
                            TEXT(xu,yu);
                        end
                    end
                end
            elseif MT == 3 % 右键点击
                if ~BF(xu,yu)
                    BF(xu,yu) = true;
                    F(xu,yu).CData = FLAG;
                    T.String = num2str(str2double(T.String) - 1);
                else
                    BF(xu,yu) = false;
                    F(xu,yu).CData = [];
                    T.String = num2str(str2double(T.String) + 1);
                end
            end
        elseif Ndata(xu,yu) > 0 % 已打开的数字区域
            [a,b] = specialgrid(xu,yu);
            if sum(BF(a,b),'all') == Ndata(xu,yu) &&...
                    sum(BF(a,b),'all') < sum(~MDATA(a,b),'all')
                C = zeros(n,'logical');
                C(a,b) = true;
                [a,b] = find(C & ~MDATA & ~BF);
                for ii = [a,b].'
                    MDATA(ii(1),ii(2)) = true;
                    if Ndata(ii(1),ii(2)) == -1
                        BF(ii(1),ii(2)) = true;
                        MDATA(ii(1),ii(2)) = false;
                        M(ii(1),ii(2)).FaceColor = [1,0,0];
                        F(ii(1),ii(2)).CData = BOMB;
                        T.String = num2str(str2double(T.String) - 1);
                        if gameActive
                            stop(timerObj);
                            gameActive = false;
                            ENDq(false);
                        end
                    else
                        M(ii(1),ii(2)).FaceColor = [1,1,1];
                        PC = [1,1,1];
                        if Ndata(ii(1),ii(2)) == 0
                            swap(ii(1),ii(2));
                        else
                            TEXT(ii(1),ii(2));
                        end
                    end
                end
            end
        end
    end
    
    % 检查游戏是否胜利
    if (all(BDATA == ~MDATA,'all') || all(BDATA == BF,'all')) && gameActive
        stop(timerObj);
        gameActive = false;
        ENDq(true);
    end
end

% 递归打开空白区域
function swap(x,y)
    C = zeros(n(1),n(2),'logical');
    C_ = C;
    C(x,y) = true;
    while ~all(C == C_,'all')
        C_ = C;
        [x,y] = find((~Ndata | BF) & C);
        for ii = [x,y].'
            if Ndata(ii(1),ii(2)) == 0
                [a,b] = specialgrid(ii(1),ii(2));
                C(a,b) = ~BF(a,b);
            end
        end
    end
    [x,y] = find(C);
    for ii = [x,y].'
        MDATA(ii(1),ii(2)) = true;
        M(ii(1),ii(2)).FaceColor = [1,1,1];
        if Ndata(ii(1),ii(2)) ~= 0
            TEXT(ii(1),ii(2));
        end
    end
end

% 获取周围格子坐标
function [a,b] = specialgrid(x,y)
    if x == 1
        a = [1,2];
    elseif x == n(1)
        a = [n(1)-1,n(1)];
    else
        a = x-1:x+1;
    end
    if y == 1
        b = [1,2];
    elseif y == n(2)
        b = [n(2)-1,n(2)];
    else
        b = y-1:y+1;
    end
end

% 显示数字
function TEXT(x,y)
    text(x,y,num2str(Ndata(x,y)),'FontSize',15,'FontWeight',...
        'bold','Color',CD(Ndata(x,y),:),'HorizontalAlignment','center');
end

% 游戏结束处理
function ENDq(a)
    if a
        elapsedTime = round(toc(startTime));
        Endbuttom = questdlg(sprintf('你赢了! 用时: %d秒', elapsedTime),'胜利',...
            '重新开始','关闭','重新开始');
    else
        % 显示所有雷的位置
        [bombX, bombY] = find(BDATA);
        for ii = 1:length(bombX)
            if ~BF(bombX(ii), bombY(ii))
                F(bombX(ii), bombY(ii)).CData = BOMB;
            end
        end
        
        elapsedTime = round(toc(startTime));
        Endbuttom = questdlg(sprintf('游戏结束. 用时: %d秒', elapsedTime),...
            '失败','重新开始','关闭','重新开始');
    end
    
    if isempty(Endbuttom)
        Endbuttom = 'end';
    end
    
    if length(Endbuttom) == 7 % 重新开始
        restartGame();
    elseif length(Endbuttom) == 5 % 关闭
        close(f1);
        delete(timerObj);
        clear;
    end
end

% 更新计时器显示
function updateTimer(~, ~)
    if gameActive
        elapsedTime = round(toc(startTime));
        timerDisplay.String = num2str(elapsedTime);
    end
end

% 重新开始游戏
function restartGame(~, ~)
    delete(timerObj);
    close(f1);
    Bomb(n, mm);
end

% 更改难度
function changeDifficulty(~, ~)
    delete(timerObj);
    close(f1);
    Bomb();
end

end
