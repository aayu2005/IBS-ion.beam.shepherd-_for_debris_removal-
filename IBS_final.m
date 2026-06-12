clc; clear; close all;

%% ========================================================================
%% PHASE 1: REAL-WORLD MISSION CONSTANTS & PROPULSION SPECIFICATIONS
%% ========================================================================
Re = 6371e3;                % Earth radius (meters)
h_sat = 600e3;              % IBS Satellite stays at a stable 600 km orbit
h_deb_start = 850e3;        % Debris starts 250 km HIGHER (850 km) for clear visual gap
h_deb_target = 400e3;       % Target de-orbit altitude dropped down to 400 km

m_sat = 50;                 % IBS Satellite Mass (kg)
m_debris = 120;             % Space Debris Target Mass (kg)
m_total = m_sat + m_debris; 

% Real Ion Engine Performance Metrics
Thrust = 0.250;             % Steady state engine thrust (Newtons)
Isp = 3200;                 % Ion propulsion specific impulse (seconds)
g0 = 9.81;                  % Standard gravity acceleration (m/s^2)
mdot = Thrust / (Isp * g0); % Fuel mass flow consumption rate (kg/s)

%% ========================================================================
%% PHASE 2: TRUE MATHEMATICAL ORBITAL DECAY SOLVER
%% ========================================================================
fprintf('Solving real-world de-orbital descent matrices...\n');

current_r = Re + h_deb_start;
target_r = Re + h_deb_target;
mu = 3.986e14;              % Earth's gravitational parameter

real_time_seconds = 0;
fuel_consumed_kg = 0;

log_points = 500;
r_history = zeros(log_points, 1);
theta_history = zeros(log_points, 1);

dt_step = 60; % Numeric integration time step (seconds)
% Estimate duration to size the log buffer intervals cleanly
est_duration = abs(target_r - current_r) / (2 * Thrust / m_total * sqrt(mu/current_r));
log_interval = max(1, round(est_duration / (dt_step * log_points)));

idx = 1;
theta = 0.4; % Initial angular phase offset so they don't sit on top of each other

while current_r > target_r
    v_orbital = sqrt(mu / current_r);
    a_thrust = Thrust / (m_total - fuel_consumed_kg);
    
    % Radial decay velocity change rate (continuous retrograde deceleration)
    dr_dt = -2 * a_thrust * current_r / v_orbital; 
    
    current_r = current_r + dr_dt * dt_step;
    real_time_seconds = real_time_seconds + dt_step;
    fuel_consumed_kg = fuel_consumed_kg + mdot * dt_step;
    
    dtheta_dt = v_orbital / current_r;
    theta = theta + dtheta_dt * dt_step;
    
    if mod(real_time_seconds / dt_step, log_interval) == 0 && idx <= log_points
        r_history(idx) = current_r;
        theta_history(idx) = theta;
        idx = idx + 1;
    end
end

r_history(idx:end) = target_r;
theta_history(idx:end) = theta;
real_days = real_time_seconds / (24 * 3600);

fprintf('Real Mission Math Resolved:\n');
fprintf(' -> Total De-orbit Duration: %.2f Days\n', real_days);
fprintf(' -> Total Propellant Used  : %.4f kg\n\n', fuel_consumed_kg);

%% ========================================================================
%% PHASE 3: MAP VISUAL GEOMETRY ARRAYS
%% ========================================================================
num_frames = log_points;

% Satellite orbits continuously in its circular track
theta_sat = linspace(0, 16*pi, num_frames)'; 
x = (Re + h_sat) * cos(theta_sat);
y = (Re + h_sat) * sin(theta_sat);
z = zeros(num_frames, 1);

% Debris spirals downward from its distinct outer orbit path
x_d = r_history .* cos(theta_history);
y_d = r_history .* sin(theta_history);
z_d = zeros(num_frames, 1);

%% ========================================================================
%% PHASE 4: RENDER GRAPHICS ENVIRONMENT
%% ========================================================================
fig = figure('Color', 'k', 'Name', 'IBS Mission Analytics Dashboard', 'Position', [50, 50, 1150, 800]);
[X, Y, Z] = sphere(100);
try
    img = imread('map.jpg');
    surf(Re*X, Re*Y, -Re*Z, 'FaceColor', 'texturemap', 'EdgeColor', 'none', 'CData', img);
catch
    surf(Re*X, Re*Y, Re*Z, 'FaceColor', [0.05 0.12 0.3], 'EdgeColor', 'none', 'FaceAlpha', 0.8); 
end
hold on; axis equal; grid off; axis off;
lighting gouraud; camlight; view(3); rotate3d on;

scale = 160e3; 
debris_visual_scale = scale * 1.1;

[xc, yc, zc] = unit_box(1*scale, 1*scale, 3*scale);
cubesat_chassis = surf(xc, yc, zc, 'FaceColor', [0.75 0.75 0.8], 'EdgeColor', [0.1 0.1 0.1]);

[x_panel, y_panel, z_panel] = unit_box(4.0*scale, 0.05*scale, 2.5*scale);
solar_wing_left  = surf(x_panel, y_panel, z_panel, 'FaceColor', [0.1 0.3 0.6], 'EdgeColor', 'none');
solar_wing_right = surf(x_panel, y_panel, z_panel, 'FaceColor', [0.1 0.3 0.6], 'EdgeColor', 'none');

[xd_mesh, yd_mesh, zd_mesh] = sphere(12);
debris_mesh = surf(debris_visual_scale*xd_mesh, debris_visual_scale*yd_mesh, debris_visual_scale*zd_mesh, ...
    'FaceColor', [0.6 0.55 0.55], 'EdgeColor', [0.2 0.2 0.2]);

[ubeam, vbeam, wbeam] = cylinder([0.1 1.0], 24);
ubeam = ubeam * 1.2e5; vbeam = vbeam * 1.2e5;
ion_beam = surf(ubeam, vbeam, wbeam, 'FaceColor', [0 0.8 1], 'EdgeColor', 'none', 'FaceAlpha', 0.4);

% Pre-plot clear orbital paths to highlight the visual space gap
plot3(x, y, z, 'g:', 'LineWidth', 1.0, 'SeriesIndex', 1); % Satellite track reference
sat_trail = plot3(x(1), y(1), z(1), 'g-', 'LineWidth', 1.5);
deb_trail = plot3(x_d(1), y_d(1), z_d(1), 'r-', 'LineWidth', 1.5);

x_d_trail = zeros(num_frames, 1);
y_d_trail = zeros(num_frames, 1);
z_d_trail = zeros(num_frames, 1);

%% ========================================================================
%% PHASE 5: RUNTIME MISSION RENDERING ANIMATION LOOP
%% ========================================================================
for k = 1:num_frames
    current_fraction = k / num_frames;
    current_time_days = real_days * current_fraction;
    current_fuel_kg = fuel_consumed_kg * current_fraction;
    
    P_sat = [x(k); y(k); z(k)];
    P_deb = [x_d(k); y_d(k); z_d(k)];
    
    vec_to_debris = P_deb - P_sat;
    distance = norm(vec_to_debris);
    if distance < 1e-6, distance = 1e-6; end
    
    %% ATTITUDE ALIGNMENT ENGINE
    z_body = vec_to_debris / distance;
    x_body = cross([0;0;1], z_body);
    nx = norm(x_body);
    if nx < 1e-8, x_body = [1;0;0]; else, x_body = x_body/nx; end
    y_body = cross(z_body, x_body);
    R = [x_body, y_body, z_body];
    
    %% GEOMETRY PIPELINE RE-RENDERING
    update_geometry(cubesat_chassis, xc, yc, zc, R, P_sat);
    update_geometry(solar_wing_left,  x_panel, y_panel, z_panel, R, P_sat - R*([0; 0.8*scale; 0]));
    update_geometry(solar_wing_right, x_panel, y_panel, z_panel, R, P_sat + R*([0; 0.8*scale; 0]));
    
    set(debris_mesh, 'XData', debris_visual_scale * xd_mesh + P_deb(1), ...
                     'YData', debris_visual_scale * yd_mesh + P_deb(2), ...
                     'ZData', debris_visual_scale * zd_mesh + P_deb(3));
                 
    wbeam_scaled = wbeam * distance;
    update_geometry(ion_beam, ubeam, vbeam, wbeam_scaled, R, P_sat);
    
    % Trace dynamic trails
    x_d_trail(k) = P_deb(1); y_d_trail(k) = P_deb(2); z_d_trail(k) = P_deb(3);
    set(sat_trail, 'XData', x(1:k), 'YData', y(1:k), 'ZData', z(1:k));
    set(deb_trail, 'XData', x_d_trail(1:k), 'YData', y_d_trail(1:k), 'ZData', z_d_trail(1:k));
    
    %% TRUE DATA METRICS HUD DISPLAY
    deb_altitude = (norm(P_deb) - Re) / 1000; 
    title(sprintf(['REAL DE-ORBIT MISSION PROFILE\\n' ...
                   'Elapsed Mission Time: %.2f Days | Real Fuel Expended: %.4f kg\\n' ...
                   'IBS Tracking Range: %.1f km | Real Debris Altitude: %.1f km\\n' ...
                   'Status: Active Ion Braking (Retrograde Momentum Transfer Drop)'], ...
        current_time_days, current_fuel_kg, distance/1000, deb_altitude), ...
        'Color', 'w', 'FontSize', 11);
    
    % Set camera perspective to capture the altitude cross-section gap
    view(0, 90); % Top-down 2D plane look to clearly monitor space gap width
    camtarget([0, 0, 0]); % Center focus on Earth to see orbits shrink relative to globe
    
    drawnow limitrate;
    pause(0.04);
end

fprintf('=== FINAL FLIGHT DATA REPORT ===\n');
fprintf('Real-World Duration Required : %.2f Days\n', real_days);
fprintf('Total Xenon Fuel Mass Burned : %.4f kg\n', fuel_consumed_kg);
fprintf('Final Entry Altitude Reached : %.2f km\n', h_target/1000);

%% ========================================================================
%% AUXILIARY REUSEABLE ROTATION ENGINE FUNCTIONS
%% ========================================================================
function [X,Y,Z] = unit_box(dx,dy,dz)
X = [-1  1  1 -1 -1; -1  1  1 -1 -1] * dx/2;
Y = [-1 -1  1  1 -1; -1 -1  1  1 -1] * dy/2;
Z = [-1 -1 -1 -1 -1;  1  1  1  1  1] * dz/2;
end

function update_geometry(handle, x0, y0, z0, R, translation)
    orig_pts = [x0(:), y0(:), z0(:)];
    rot_pts = orig_pts * R';
    new_X = reshape(rot_pts(:,1), size(x0)) + translation(1);
    new_Y = reshape(rot_pts(:,2), size(y0)) + translation(2);
    new_Z = reshape(rot_pts(:,3), size(z0)) + translation(3);
    set(handle, 'XData', new_X, 'YData', new_Y, 'ZData', new_Z);
end