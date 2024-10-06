function objects_main
    global objects
    global pgons
    global pgonplots
    objects = {};
    pgons = {};
    pgonplots = {};
    
    main_fig = uifigure("Position", [0 0 900 900],'Toolbar','none');
    main_fig.Name = "nosnoc objects";

    gl = uigridlayout(main_fig,[1 1]);

    gl.RowHeight = {'1x'};
    gl.ColumnWidth = {'1x'};

    % menu
    menu = uimenu(main_fig, 'Text', 'Add Object');
    add_ball = uimenu(menu,'Text', 'Ball');
    add_ellipse = uimenu(menu,'Text', 'Ellipse');

    % Position axes
    ax = uiaxes(gl);
    ax.Layout.Row = 1;
    ax.Layout.Column = 1;

    cm = uicontextmenu(main_fig);
    ball = uimenu(cm,"Text","Add Ball");
    ellipse = uimenu(cm,"Text","Add Ellipse");
    ax.ContextMenu = cm;
    axis(ax, 'equal')

    axis(ax, 'manual');
    
    ball.MenuSelectedFcn = @add_ball;
    ellipse.MenuSelectedFcn = @add_ellipse;
end

function add_ball(context, info)
    global objects
    center = info.Source.Parent.Parent.CurrentObject.CurrentPoint;
    center = center(1,1:2);
    radius = 1;
    ball = nosnoc.objects.Ball(radius, 2);
    ball.x0 = center';
    objects = [objects, {ball}];
    plot_objects(info.Source.Parent.Parent.CurrentObject);
end

function add_ellipse(context, info)
    global objects
    center = info.Source.Parent.Parent.CurrentObject.CurrentPoint;
    center = center(1,1:2);
    radius = 1;
    ellipse = nosnoc.objects.Ellipse(diag([2,1]));
    ellipse.x0 = [center';0];
    objects = [objects, {ellipse}];
    plot_objects(info.Source.Parent.Parent.CurrentObject);
end

function plot_objects(ax)
    global objects
    global pgonplots

    cla(ax);
    hold(ax,'on')
    for ii=1:length(objects)
        obj = objects{ii};
        poly = obj.to_polygon();
        if numel(obj.x0) == 2
            pgonplots{ii}.poly = plot(ax, translate(poly, obj.x0(1:2)'));
            pgonplots{ii}.center = plot(ax, obj.x0(1), obj.x0(2), 'or', 'ButtonDownFcn', {@center_move,'down'});
            pgonplots{ii}.edge = plot(ax, obj.x0(1) + obj.r, obj.x0(2), 'or', 'ButtonDownFcn', {@radius_move,'down'});
            pgonplots{ii}.center.UserData.index = ii;
            pgonplots{ii}.edge.UserData.index = ii;
        elseif numel(obj.x0) == 3
            pgonplots{ii}.poly = plot(ax, translate(rotate(poly, rad2deg(obj.x0(3))), obj.x0(1:2)'));%, 'FaceColor', facecolors{ii}, 'FaceAlpha', 1, 'EdgeColor', linecolors{ii});
            phi = obj.x0(3);
            R = [cos(phi), -sin(phi);
                sin(phi), cos(phi)];
            pgonplots{ii}.center = plot(ax, obj.x0(1), obj.x0(2), 'or', 'ButtonDownFcn', {@center_move,'down'});
            A = obj.A{1};
            a1 = A(1,1);
            a2 = A(2,2);
            v1 = obj.x0(1:2) + R*[inv(sqrt(a1));0];
            v2 = obj.x0(1:2) + R*[0;inv(sqrt(a2))];
            v3 = obj.x0(1:2) + R*[sqrt(1/(a1 + (tan(pi/4)^2)*a2)); tan(pi/4)*sqrt(1/(a1 + (tan(pi/4)^2)*a2))];
            pgonplots{ii}.edge1 = plot(ax, v1(1), v1(2), 'or', 'ButtonDownFcn', {@radius1_move,'down'});
            pgonplots{ii}.edge2 = plot(ax, v2(1), v2(2), 'or', 'ButtonDownFcn', {@radius2_move,'down'});
            pgonplots{ii}.edge3 = plot(ax, v3(1), v3(2), 'or', 'ButtonDownFcn', {@radius3_move,'down'});
            pgonplots{ii}.center.UserData.index = ii;
            pgonplots{ii}.edge1.UserData.index = ii;
            pgonplots{ii}.edge2.UserData.index = ii;
            pgonplots{ii}.edge3.UserData.index = ii;
        end
    end
    hold(ax,'off')
end

function update_objects(ax)
    global objects
    global pgonplots

    hold(ax,'on')
    for ii=1:length(objects)
        obj = objects{ii};
        poly = obj.to_polygon();
        if numel(obj.x0) == 2
            color = pgonplots{ii}.poly.FaceColor;
            delete(pgonplots{ii}.poly);
            pgonplots{ii}.poly = plot(ax, translate(poly, obj.x0(1:2)'), "FaceColor", color);
            pgonplots{ii}.center.XData = obj.x0(1);
            pgonplots{ii}.center.YData = obj.x0(2);
            pgonplots{ii}.edge.XData = obj.x0(1) + obj.r;
            pgonplots{ii}.edge.YData = obj.x0(2);
        elseif numel(obj.x0) == 3
            color = pgonplots{ii}.poly.FaceColor;
            delete(pgonplots{ii}.poly);
            pgonplots{ii}.poly = plot(ax, translate(rotate(poly, rad2deg(obj.x0(3))), obj.x0(1:2)'),  "FaceColor", color);
            phi = obj.x0(3);
            R = [cos(phi), -sin(phi);
                sin(phi), cos(phi)];
            pgonplots{ii}.center.XData = obj.x0(1);
            pgonplots{ii}.center.YData = obj.x0(2);
            A = obj.A{1};
            a1 = A(1,1);
            a2 = A(2,2);
            v1 = obj.x0(1:2) + R*[inv(sqrt(a1));0];
            v2 = obj.x0(1:2) + R*[0;inv(sqrt(a2))];
            v3 = obj.x0(1:2) + R*[sqrt(1/(a1 + (tan(pi/4)^2)*a2)); tan(pi/4)*sqrt(1/(a1 + (tan(pi/4)^2)*a2))];
            pgonplots{ii}.edge1.XData = v1(1);
            pgonplots{ii}.edge1.YData = v1(2);
            pgonplots{ii}.edge2.XData = v2(1);
            pgonplots{ii}.edge2.YData = v2(2);
            pgonplots{ii}.edge3.XData = v3(1);
            pgonplots{ii}.edge3.YData = v3(2);
        end
    end
    hold(ax,'off')
end


function center_move(context,info,action)
    global objects
    persistent curr xdata ydata
    switch action
      case 'down'
        ax = context.Parent;
        fig = ax.Parent.Parent;
        pos = ax.CurrentPoint;
        pos = pos(1,1:2);
        curr = context;
        xdata = context.XData;
        ydata = context.YData;
        set(fig,...
            'WindowButtonMotionFcn',  {@center_move,'move'},...
            'WindowButtonUpFcn',      {@center_move,'up'});
      case 'move'
        % horizonal move move
        pos = curr.Parent.CurrentPoint(1,1:2);
        curr.XData = pos(1);
        curr.YData = pos(2);
        objects{curr.UserData.index}.x0(1:2) = [curr.XData;curr.YData];
        update_objects(curr.Parent);
      case 'up'
        objects{curr.UserData.index}.x0(1:2) = [curr.XData;curr.YData];
        set(curr.Parent.Parent.Parent,...
            'WindowButtonMotionFcn',  '',...
            'WindowButtonUpFcn',      '');
       plot_objects(curr.Parent);
    end
end

function radius_move(context,info,action)
    global objects pgonplots
    persistent curr xdata ydata
    switch action
      case 'down'
        ax = context.Parent;
        fig = ax.Parent.Parent;
        pos = ax.CurrentPoint;
        pos = pos(1,1:2);
        curr = context;
        xdata = context.XData;
        ydata = context.YData;
        set(fig,...
            'WindowButtonMotionFcn',  {@radius_move,'move'},...
            'WindowButtonUpFcn',      {@radius_move,'up'});
      case 'move'
        % horizonal move move
        pos = curr.Parent.CurrentPoint(1,1:2);
        curr.XData = pos(1);
        ii = curr.UserData.index;
        objects{ii}.r = abs(pgonplots{ii}.center.XData - curr.XData);
        update_objects(curr.Parent);
      case 'up'
        ii = curr.UserData.index;
        objects{ii}.r = abs(pgonplots{ii}.center.XData - curr.XData);
        set(curr.Parent.Parent.Parent,...
            'WindowButtonMotionFcn',  '',...
            'WindowButtonUpFcn',      '');
       plot_objects(curr.Parent);
    end
end

function radius1_move(context,info,action)
    global objects pgonplots
    persistent curr xdata ydata vec
    switch action
      case 'down'
        ax = context.Parent;
        fig = ax.Parent.Parent;
        pos = ax.CurrentPoint;
        pos = pos(1,1:2);
        curr = context;
        obj = objects{curr.UserData.index};
        phi = obj.x0(3);
        R = [cos(phi), -sin(phi);
            sin(phi), cos(phi)];
        A = obj.A{1};
        a1 = A(1,1);
        a2 = A(2,2);
        vec = R*[inv(sqrt(a1));0];
        set(fig,...
            'WindowButtonMotionFcn',  {@radius1_move,'move'},...
            'WindowButtonUpFcn',      {@radius1_move,'up'});
      case 'move'
        % horizonal move move
        pos = curr.Parent.CurrentPoint(1,1:2)';
        obj = objects{curr.UserData.index};
        pos = pos - obj.x0(1:2);
        pos = obj.x0(1:2) + (dot(pos,vec)/dot(vec,vec))*vec;
        curr.XData = pos(1);
        curr.YData = pos(2);
        ii = curr.UserData.index;
        A = objects{ii}.A{1};
        dist = norm([pgonplots{ii}.center.XData;pgonplots{ii}.center.YData] - [curr.XData;curr.YData]);
        A(1,1) = 1/(dist^2);
        objects{ii}.A{1} = A;
        update_objects(curr.Parent);
      case 'up'
        ii = curr.UserData.index;
        A = objects{ii}.A{1};
        dist = norm([pgonplots{ii}.center.XData;pgonplots{ii}.center.YData] - [curr.XData;curr.YData]);
        A(1,1) = 1/(dist^2);
        objects{ii}.A{1} = A;
        set(curr.Parent.Parent.Parent,...
            'WindowButtonMotionFcn',  '',...
            'WindowButtonUpFcn',      '');
       plot_objects(curr.Parent);
    end
end

function radius2_move(context,info,action)
    global objects pgonplots
    persistent curr xdata ydata vec
    switch action
      case 'down'
        ax = context.Parent;
        fig = ax.Parent.Parent;
        pos = ax.CurrentPoint;
        pos = pos(1,1:2);
        curr = context;
        obj = objects{curr.UserData.index};
        phi = obj.x0(3);
        R = [cos(phi), -sin(phi);
            sin(phi), cos(phi)];
        A = obj.A{1};
        a1 = A(1,1);
        a2 = A(2,2);
        vec = R*[0;inv(sqrt(a2))];
        set(fig,...
            'WindowButtonMotionFcn',  {@radius2_move,'move'},...
            'WindowButtonUpFcn',      {@radius2_move,'up'});
      case 'move'
        % horizonal move move
        pos = curr.Parent.CurrentPoint(1,1:2)';
        obj = objects{curr.UserData.index};
        pos = pos - obj.x0(1:2);
        pos = obj.x0(1:2) + (dot(pos,vec)/dot(vec,vec))*vec;
        curr.XData = pos(1);
        curr.YData = pos(2);
        ii = curr.UserData.index;
        A = objects{ii}.A{1};
        dist = norm([pgonplots{ii}.center.XData;pgonplots{ii}.center.YData] - [curr.XData;curr.YData]);
        A(2,2) = 1/(dist^2);
        objects{ii}.A{1} = A;
        update_objects(curr.Parent);
      case 'up'
        ii = curr.UserData.index;
        A = objects{ii}.A{1};
        dist = norm([pgonplots{ii}.center.XData;pgonplots{ii}.center.YData] - [curr.XData;curr.YData]);
        A(2,2) = 1/(dist^2);
        objects{ii}.A{1} = A;
        set(curr.Parent.Parent.Parent,...
            'WindowButtonMotionFcn',  '',...
            'WindowButtonUpFcn',      '');
       plot_objects(curr.Parent);
    end
end

function radius3_move(context,info,action)
    global objects
    persistent curr xdata ydata vec
    switch action
      case 'down'
        ax = context.Parent;
        fig = ax.Parent.Parent;
        pos = ax.CurrentPoint;
        pos = pos(1,1:2);
        curr = context;
        xdata = context.XData;
        ydata = context.YData;
        obj = objects{curr.UserData.index};
        phi = obj.x0(3);
        R = [cos(phi), -sin(phi);
            sin(phi), cos(phi)];
        A = obj.A{1};
        a1 = A(1,1);
        a2 = A(2,2);
        vec = R*[sqrt(1/(a1 + (tan(pi/4)^2)*a2)); tan(pi/4)*sqrt(1/(a1 + (tan(pi/4)^2)*a2))];
        set(fig,...
            'WindowButtonMotionFcn',  {@radius3_move,'move'},...
            'WindowButtonUpFcn',      {@radius3_move,'up'});
      case 'move'
        % horizonal move move
        pos = curr.Parent.CurrentPoint(1,1:2)';
        obj = objects{curr.UserData.index};
        pos = pos - obj.x0(1:2);
        theta = cart2pol(pos(1),pos(2));
        [x,y] = pol2cart(theta, norm(vec));
        pos = obj.x0(1:2) + [x;y];
        curr.XData = pos(1);
        curr.YData = pos(2);
        obj = objects{curr.UserData.index};
        pos = [curr.XData;curr.YData] - obj.x0(1:2);
        theta = cart2pol(pos(1),pos(2));
        obj.x0(3) = theta - pi/4;
        update_objects(curr.Parent);
      case 'up'
        obj = objects{curr.UserData.index};
        pos = [curr.XData;curr.YData] - obj.x0(1:2);
        theta = cart2pol(pos(1),pos(2));
        obj.x0(3) = theta - pi/4;
        set(curr.Parent.Parent.Parent,...
            'WindowButtonMotionFcn',  '',...
            'WindowButtonUpFcn',      '');
       plot_objects(curr.Parent);
    end
end
