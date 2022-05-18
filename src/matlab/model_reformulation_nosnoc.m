%
%    This file is part of NOSNOC.
%
%    NOS-NOC -- A software for NOnSmooth Numerical Optimal Control.
%    Copyright (C) 2022 Armin Nurkanovic, Moritz Diehl (ALU Freiburg).
%
%    NOS-NOC is free software; you can redistribute it and/or
%    modify it under the terms of the GNU Lesser General Public
%    License as published by the Free Software Foundation; either
%    version 3 of the License, or (at your option) any later version.
%
%    NOS-NOC is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%    Lesser General Public License for more details.
%
%    You should have received a copy of the GNU Lesser General Public
%    License along with NOS-NOC; if not, write to the Free Software Foundation,
%    Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
%
%
function [model,settings] = model_reformulation_nosnoc(model,settings)
import casadi.*
%% Load settings and model details
if ~settings.time_freezing_model_exists && settings.time_freezing 
    % check is the model generated if time freezing is used
     [model,settings] = time_freezing_reformulation(model,settings);
end

unfold_struct(model,'caller');
unfold_struct(settings,'caller')


%% Determine is the SX or MX mode in CasADi used.
casadi_symbolic_mode = model.x(1).type_name();
settings.casadi_symbolic_mode  = casadi_symbolic_mode;
settings.couple_across_stages = 1;
%% Step-size
h = T/N_stages;
% nominal lengths of the finite elements for different control intevrals, every control interval might have a different number of finite elements.
N_finite_elements = N_finite_elements(:); % make a column vector of the input
if length(N_finite_elements) > N_stages
    N_finite_elements = N_finite_elements(1:N_stages);
    if print_level >=1
        fprintf('Info: Provided N_finite_elements had more antries then N_stages, the surplus of entries was removed. \n')
    end
end
if length(N_finite_elements) == 1
    N_finite_elements = N_finite_elements*ones(N_stages,1);
elseif length(N_finite_elements) > 1 && length(N_finite_elements) < N_stages
    N_finite_elements = N_finite_elements(:); % make sure it is a column vector
    N_finite_elements = [N_finite_elements;N_finite_elements(end)*ones(N_stages-length(N_finite_elements),1)];
end
h_k = h./N_finite_elements;

model.h = h;
model.h_k = h_k;
model.N_finite_elements = N_finite_elements;

%% Check is x

if exist('x')
    n_x = length(x);
    % check  lbx
    if exist('lbx')
        if length(lbx) ~= n_x
            error('The vector lbx, for the lower bounds of x has the wrong size.')
        end
    else
        lbx = -inf*ones(n_x,1);
    end
    % check ubx
    if exist('ubx')
        if length(ubx) ~= n_x
            error('The vector ubx, for the upper bounds of x has the wrong size.')
        end
    else
        ubx = inf*ones(n_x,1);
    end
else
    error('Please provide the state vector x, a CasADi symbolic variable.')
end
%% Check is u provided
if exist('u')
    n_u = length(u);
    % check  lbu
    if exist('lbu')
        if length(lbu) ~= n_u
            error('The vector lbu, for the lower bounds of u has the wrong size.')
        end
    else
        lbu = -inf*ones(n_u,1);
    end
    % check ubu
    if exist('ubu')
        if length(ubu) ~= n_u
            error('The vector ubu, for the upper bounds of u has the wrong size.')
        end
    else
        ubu = inf*ones(n_u,1);
    end
    % check u0
    if exist('u0')
        if length(u0) ~= n_u
            error('The vector u0, for the initial guess of u has the wrong size.')
        end
    else
        u0 = 0*ones(n_u,1);
    end
else
    n_u = 0;
    if print_level >=1
        fprintf('Info: No control vector u is provided. \n')
    end
    lbu = [];
    ubu = [];
end

%% Stage and terminal costs
if ~exist('f_q')
    if print_level >=1
        fprintf('Info: No stage cost is provided. \n')
    end
%     eval(['f_q = ', casadi_symbolic_mode, '.zeros(1);'])
      f_q = 0;
end
if exist('f_q_T')
    terminal_cost = 1;
else
    if print_level >=1
        fprintf('Info: No terminal cost is provided. \n')
    end
%     eval(['f_q_T = ', casadi_symbolic_mode, '.zeros(1);'])
    f_q_T = 0;
end

%% Inequality constraints
if exist('g_ineq')
    g_ineq_constraint  = 1;
    n_g_ineq = length(g_ineq);
    if exist('g_ineq_lb')
        if length(g_ineq_lb)~=n_g_ineq;
            error('The user provided vector g_ineq_lb has the wrong size.')
        end
    else
        g_ineq_lb = -inf*ones(n_g_ineq,1);
    end

    if exist('g_ineq_ub')
        if length(g_ineq_ub)~=n_g_ineq;
            error('The user provided vector g_ineq_ub has the wrong size.')
        end
    else
        g_ineq_ub =  0*ones(n_g_ineq,1);
    end
    g_ineq_fun  = Function('g_ineq_fun',{x,u},{g_ineq});
else
    n_g_ineq = 0;
    g_ineq_constraint  = 0;
    if print_level >=1
        fprintf('Info: No path constraints are provided. \n')
    end
end


%% Terminal constraints
if exist('g_terminal')
    terminal_constraint = 1;
    n_g_terminal = length(g_terminal);
    if exist('g_terminal_lb')
        if length(g_terminal_lb)~=n_g_terminal;
            error('The user provided vector g_terminal_lb has the wrong size.')
        end
    else
        g_terminal_lb = 0*ones(n_g_terminal,1);
    end

    if exist('g_terminal_ub')
        if length(g_terminal_ub)~=n_g_terminal;
            error('The user provided vector g_terminal_ub has the wrong size.')
        end
    else
        g_terminal_ub =  0*ones(n_g_terminal,1);
    end
    g_terminal_fun  = Function('g_terminal_fun',{x},{g_terminal});
else
    terminal_constraint = 0;
    n_g_terminal = 0;
    if print_level >=1
        fprintf('Info: No terminal constraints are provided. \n')
    end
end

%% Transforming a Piecewise smooth system into a DCS via Stewart's or the Step function approach
pss_mode = settings.pss_mode;
% Stewart's representation of the sets R_i and discirimant functions g_i
g_ind_all = {};
g_ind_vec = [];
c_all = [];
m_vec = [];
n_c_vec = [];

if ~exist('F')
    error('Matrix F (or matrices F_i) with PSS modes not provided.');
else
    % check how many subsystems are present
    if iscell(F)
        n_simplex = length(F);
    else
        F = {F};
        n_simplex = 1;
    end
    % extract dimensions of subystems
    for ii = 1:n_simplex
        m_temp = size(F{ii},2);
        m_vec  = [m_vec m_temp];
    end
end

if ~exist('S')
    % if not the matrix S is provided, maybe the g_ind are avilable
    % directly?
    if isequal(pss_mode,'Stewart')
        if exist('g_ind')
            if ~iscell(g_ind)
                g_ind = {g_ind};
            end

            for ii = 1:n_simplex
                % discrimnant functions
                g_ind_vec =  [g_ind_vec;g_ind{ii};];
                g_ind_all{ii} = g_ind{ii};
                c_all = [c_all; 0];
            end
        else
            error(['Neither the sign matrix S nor the indicator functions g_ind for regions are provided. ' ...
                'Either provide the matrix S and the expression for c, or the expression for g_ind.']);
        end
    else
        error(['The user usses settings.pss_mode = ''Step'', but the sign matrix S is not provided. Please provide the matrix S and the expressions for c(x) (definfing the region boundaries).']);
    end
else
    % Check if all data is avilable and if dimensions match.
    if ~iscell(S)
        S = {S};
    end
    if length(S) ~= n_simplex
        error('Number of matrices S does not match number of subsystems. Note that the number of subsystems is taken to be number of matrices F_i which collect the modes of every subsystem.')
    end
    % Check constraint function c
    if ~exist('c')
        error('Expreesion for c, the constraint function for regions R_i is not provided.');
    else
        if ~iscell(c)
            c = {c};
        end
        if length(c) ~= n_simplex
            error('Number of different expressions for c does not match number of subsystems (taken to be number of matrices F_i which collect the modes of every subsystem).')
        end
    end

    % check are the matrices dense
    if isequal(pss_mode,'Stewart')
        for ii = 1:n_simplex
            if any(sum(abs(S{ii}),2)<size(S{ii},2))
                if n_simplex == 1
                    error('The matrix S is not dense. Either provide a dense matrix or use settings.mode = ''Step''.');
                else
                    error(['The matrix S{' num2str(ii) '} of the provided matrices is not dense. Either provide all dense matrices or use settings.mode = ''Step''.']);
                end
            end
        end
    end

    for ii = 1:n_simplex
        if size(S{ii},2) ~= length(c{ii})
            error('The matrix S and vector c do not have compatible dimension.');
        end

        % discrimnant functions
        switch pss_mode
            case 'Stewart'
                % Create Stewart's indicator functions g_ind_ii
                g_ind_all{ii} = -S{ii}*c{ii};
                g_ind_vec = [g_ind_vec ;-S{ii}*c{ii}];
            case 'Step'
                %eval(['c_' num2str(ii) '= c{ii};']);
        end
        % dimensions of c
        c_all = [c_all; c{ii}];
        n_c{ii} = length(c{ii});
        n_c_vec  = [n_c_vec;length(c{ii})];
    end

end

% index sets and dimensions for ubsystems
m_ind_vec = [cumsum(m_vec)-m_vec(1)+1]; % index ranges of the corresponding thetas and lambdas
m = sum(m_vec);

if isempty(n_c_vec)
    n_c_vec = 0;
end

if max(n_c_vec) < 2 && isequal(pss_mode,'Step')
    pss_lift_step_functions = 0;
    if print_level >=1
        fprintf('Info: settings.pss_lift_step_functions set to 0, as are step fucntion selections are already entering the ODE linearly.\n')
    end
end

%% Parameters
sigma = define_casadi_symbolic(casadi_symbolic_mode,'sigma');
n_param = 1;  % number of parameters,  we model it as control variables and merge them with simple equality constraints
p = [sigma];
n_p = 1;

%% Algebraic variables defintion
% Dummy variavles for Stewart representation'
theta = [];
mu = [];
lambda = [];
% structs storing all vectors of every subsystem (they might have different dimensions)
theta_all = {};
lambda_all = {};
mu_all = {};
e_ones_all = {};


% dummy values for Step representation
alpha  = [];
lambda_0 = [];
lambda_1 = [];
upsilon  = [];

alpha_all  = {};
lambda_0_all = {};
lambda_1_all = {};
upsilon_all = {};

n_alpha = 0;
e_alpha = [];
n_beta = 0;
n_gamma = 0;
n_lambda_0 = 0;
n_lambda_1 = 0;
g_lift_beta = [];
g_lift_gamma  =[];
switch pss_mode
    case 'Stewart'
        % dimensions
        n_theta = sum(m_vec); % number of modes
        n_lambda = n_theta;
        n_f = n_theta;
        n_z = n_theta+n_lambda+n_simplex; % n_theta + n_lambda + n_mu
        % Define symbolic variables for algebraci equtions.
        for ii = 1:n_simplex
            ii_str = num2str(ii);
            % define theta (Filippov multiplers)
            theta_temp = define_casadi_symbolic(casadi_symbolic_mode,['theta_' ii_str],m_vec(ii));
            theta = [theta;theta_temp];
            theta_all{ii} = theta_temp;
            % define mu_i (Lagrange multipler of e'theta =1;)
            mu_temp = define_casadi_symbolic(casadi_symbolic_mode,['mu_' ii_str],1);
            mu = [mu;mu_temp];
            mu_all{ii} = mu_temp;
            % define lambda_i (Lagrange multipler of theta >= 0;)
            lambda_temp = define_casadi_symbolic(casadi_symbolic_mode,['lambda_' ii_str],m_vec(ii));
            lambda = [lambda;lambda_temp];
            lambda_all{ii} = lambda_temp;
            % adefine ppropiate vector of ones (the struct below stores them for every mode)
            e_ones_all{ii} = ones(m_vec(ii),1);
        end
    case 'Step'
        n_alpha = sum(n_c_vec);
        n_f = sum(m_vec);
        n_lambda_0 = sum(n_c_vec);
        n_lambda_1 = sum(n_c_vec);
        % for creae_nlp_fesd
        n_theta = 2*n_alpha;
        n_lambda = n_lambda_0+n_lambda_1;
        % algebraic varaibles so far
        n_z = n_alpha+n_lambda_0+n_lambda_1;
        for ii = 1:n_simplex
            ii_str = num2str(ii);
            % define alpha (selection of a set valued step function)
            alpha_temp = define_casadi_symbolic(casadi_symbolic_mode,['alpha_' ii_str],n_c_vec(ii));
            alpha = [alpha;alpha_temp];
            alpha_all{ii} = alpha_temp;
            % define lambda_0_i (Lagrange multipler of alpha >= 0;)
            lambda_0_temp = define_casadi_symbolic(casadi_symbolic_mode,['lambda_0_' ii_str],n_c_vec(ii));
            lambda_0 = [lambda_0;lambda_0_temp];
            lambda_0_all{ii} = lambda_0_temp;
            % define lambda_1_i (Lagrange multipler of alpha <= 1;)
            lambda_1_temp = define_casadi_symbolic(casadi_symbolic_mode,['lambda_1_' ii_str],n_c_vec(ii));
            lambda_1 = [lambda_1;lambda_1_temp];
            lambda_1_all{ii} = lambda_1_temp;
        end
        % adefine ppropiate vector of ones % for the kkt conditions of the LP
        e_alpha = ones(n_alpha,1);

        % Define already here lifting variables and functions
        beta = [];
        gamma = [];

        % Upsilo collects the vector for dotx = F(x)Upsilon, it is either multiaffine
        % terms or gamma from lifting
%         pss_lift_step_functions = 0;
        for ii = 1:n_simplex
                upsilon_temp = [];
                ii_str = num2str(ii);
                S_temp = S{ii};
            if pss_lift_step_functions
%                 [n_f_i,n_c_i] = size(S_temp);
%                 n_R_i = sum(abs(S_temp),2);
%                 % define gamma which etner the odes r.h.s. linearly
%                 eval(['gamma_' i_str ' = ' casadi_symbolic_mode '.sym(''gamma_' i_str ''',n_f_i);']);
%                 eval(['gamma = [gamma; gamma_' i_str '];']);
%                
%                 eval(['g_lift_beta_' i_str ' = [];']);
%                 eval(['g_lift_gamma_' i_str ' = [];']);
% 
%                 temp = ones(n_f_i,1);
%                 S_temp_reduced  = S_temp;
%                 ind_progress = 0;
%                 for ii = 1:n_c_i
%                     n_R_i = sum(abs(S_temp_reduced),2);
%                     ind_done = find(n_R_i >= ii);
%                     eval(['temp = (temp).*((1-S_temp_reduced(ind_done,ii))/2+S_temp_reduced(ind_done,ii).*alpha_' i_str '(ii));'])
%                     ind_done= find(n_R_i == ii);
%                     ind_done_complement = find(n_R_i ~= ii);
%                     if ~isempty(ind_done)
% %                         g_lift_gamma = [g_lift_gamma ;theta(ind_progress+ind_done)-(temp(ind_done))];
%                         eval(['g_lift_gamma_' i_str '= [g_lift_gamma_' i_str ';gamma(ind_progress+ind_done)-(temp(ind_done))];'])
%                         ind_full = 1:length(temp);
% %                         temp(ind_done) = [];
%                         if isempty(ind_done_complement)
%                             temp = [];
%                         else
%                             temp = temp(ind_done_complement);
%                         end
%                         S_temp_reduced(ind_done,:) = [];
%                         ind_progress = ind_progress+ind_done(end);
%                     end
%                     % start defining betas;
%                     if ii >= n_depth_step_lifting && ii< n_c_i
%                         [temp_S_red,temp_S_IA,temp_S_IC] = unique(S_temp_reduced(:,ii) ,'rows');
%                         n_beta_ii = size(temp_S_red,1);
%                         % defin intermediate beta
%                         eval(['beta_' i_str '_' num2str(ii) '=' casadi_symbolic_mode '.sym(''beta_' i_str '_' num2str(ii) ''',n_beta_ii);'])
%                         eval(['beta = [beta; beta_' i_str '_' num2str(ii) '];'])
% %                         eval(['beta_' num2str(ii+1-n_depth_step_lifting) '=' casadi_symbolic_mode '.sym(''beta_' num2str(ii+1-n_depth_step_lifting) ',n_beta_ii);'])
%                         eval(['beta_temp =' casadi_symbolic_mode '.sym(''beta_' num2str(ii+1-n_depth_step_lifting) ''',n_beta_ii);'])
% %                         beta_temp = sym(['beta_' num2str(ii+1-n_depth_step_lifting)], [n_beta_ii 1]);
%                         eval(['g_lift_beta_' i_str '= [g_lift_beta_' i_str ';beta_temp - temp(temp_S_IA)];'])
%                         temp = beta_temp(temp_S_IC)';
%                     end
%                 end
%                 eval(['g_lift_beta = [g_lift_beta;g_lift_beta_' i_str '];'])
%                 eval(['g_lift_gamma = [g_lift_gamma;g_lift_gamma_' i_str '];'])
%                 eval(['upsilon_' i_str '= gamma_' i_str ';'])
            else
                for j = 1:size(S_temp,1)
                    upsilon_ij = 1;
                    for k = 1:size(S_temp,2)
                        % create multiafine term
                        if S_temp(j,k) ~=0
                            upsilon_ij = upsilon_ij * ( 0.5*(1-S_temp(j,k))+S_temp(j,k)*alpha_all{ii}(k) ) ;
                        end
                    end
                    upsilon_temp = [upsilon_temp;upsilon_ij];                  
                end
            end
            upsilon_all{ii} = upsilon_temp;
        end
        n_beta = length(beta);
        n_gamma = length(gamma);
        n_z = n_z + n_beta+n_gamma;
end
g_lift = [g_lift_beta; g_lift_gamma];


%% Define algerbraic variables which arise from Stewart's reformulation of a PSS into a DCS
switch pss_mode
    case 'Stewart'
        % symbolic variables
%         z = [theta;lambda;mu];
        z = [vertcat(theta_all{:});vertcat(lambda_all{:});vertcat(mu_all{:})];
        lbz = [0*ones(n_theta,1);0*ones(n_theta,1);-inf*ones(n_simplex,1)];
        ubz = [inf*ones(n_theta,1);inf*ones(n_theta,1);inf*ones(n_simplex,1)];
        % inital guess for z; % solve LP for guess;
        if lp_initalization
            [theta_guess,lambda_guess,mu_guess] = create_lp_based_guess(model);
        else
            theta_guess = initial_theta*ones(n_theta,1);
            lambda_guess = initial_lambda*ones(n_theta,1);
            mu_guess = initial_mu*ones(n_simplex,1);
        end
        z0 = [theta_guess;lambda_guess;mu_guess];
        n_lift_eq = 1;
    case 'Step'
        z = [alpha;lambda_0;lambda_1;beta;gamma];
        lbz = [0*ones(n_alpha,1);0*ones(n_alpha,1);0*ones(n_alpha,1);-inf*ones(n_beta,1);-inf*ones(n_gamma,1)];
        ubz = [ones(n_alpha,1);inf*ones(n_alpha,1);inf*ones(n_alpha,1);inf*ones(n_beta,1);inf*ones(n_gamma,1)];

        alpha_guess = initial_alpha*ones(n_alpha,1);
        lambda_0_guess = initial_lambda_0*ones(n_alpha,1);
        lambda_1_guess = initial_lambda_1*ones(n_alpha,1);
        beta_guess = initial_beta*ones(n_beta,1);
        gamma_guess = initial_gamma*ones(n_gamma,1);
        % eval functios for gamma and beta?
        z0 = [alpha_guess;lambda_0_guess;lambda_1_guess;beta_guess;gamma_guess];
        n_lift_eq =length(g_lift);
end
model.z0 = z0;
model.lbz = lbz;
model.ubz = ubz;

%% Reformulate the Filippov ODE into a DCS
f_x = zeros(n_x,1);
% rhs of ODE;

for ii = 1:n_simplex
    ii_str = num2str(ii);
    switch pss_mode
        case 'Stewart'
            f_x = f_x + F{ii}*theta_all{ii};
        case 'Step'
            f_x = f_x + F{ii}*upsilon_all{ii};
    end
end

g_z = []; % collects standard algebraic equations 0 = g_i(x) - \lambda_i - e \mu_i
g_z_convex = []; % equation for the convex multiplers 1 = e' \theta
f_comp_residual = 0; % the orthogonality conditions diag(\theta) \lambda = 0.
for ii = 1:n_simplex
    ii_str = num2str(ii);
    switch pss_mode
        case 'Stewart'
            % basic algebraic equations and complementarty condtions of the DCS
            % (Note that the cross complementarities are later defined when the discrete
            % time variables for every IRK stage in the create_nlp_nosnoc function are defined.)
            % g_ind_i - lambda_i + mu_i e_i = 0; for all i = 1,..., n_simplex
            % lambda_i'*theta_i = 0; for all i = 1,..., n_simplex
            % lambda_i >= 0;    for all i = 1,..., n_simplex
            % theta_i >= 0;     for all i = 1,..., n_simplex
            % Gradient of Lagrange Function of indicator LP
            g_z = [g_z; g_ind_all{ii}-lambda_all{ii}+mu_all{ii}*e_ones_all{ii}];
            g_z_convex = [g_z_convex;e_ones_all{ii}'*theta_all{ii}-1];
            f_comp_residual = f_comp_residual + lambda_all{ii}'*theta_all{ii};
        case 'Step'
            % c_i(x) - (lambda_1_i-lambda_0_i)  = 0; for all i = 1,..., n_simplex
            % lambda_0_i'*alpha_i  = 0; for all i = 1,..., n_simplex
            % lambda_1_i'*(e-alpha_i)  = 0; for all i = 1,..., n_simplex
            % lambda_0_i >= 0;    for all i = 1,..., n_simplex
            % lambda_1_i >= 0;    for all i = 1,..., n_simplex
            % alpha_i >= 0;     for all i = 1,..., n_simplex
            g_z = [g_z;c{ii}-lambda_1_all{ii}+lambda_0_all{ii}];
            f_comp_residual = f_comp_residual + lambda_0_all{ii}'*alpha_all{ii}+lambda_1_all{ii}'*(ones(n_c_vec(ii),1)-alpha_all{ii});
    end
end
g_lp = [g_z;g_z_convex;g_lift];
n_algebraic_constraints  = length(g_lp);
%% CasADi functions for indictaor and region constraint functions
% model equations
if n_u >0
    g_ind_all_fun = Function('g_ind_all_fun',{x,u},{g_ind_vec});
    c_fun = Function('c_fun',{x,u},{c_all});
else
    g_ind_all_fun = Function('g_ind_all_fun',{x},{g_ind_vec});
    c_fun = Function('c_fun',{x},{c_all});
end

if n_u >0
    f_x_fun = Function('f_x_fun',{x,z,u},{f_x,f_q});
    g_lp_fun = Function('g_lp_fun',{x,z,u},{g_lp}); % lp kkt conditions without bilinear complementarity term (it is treated with the other c.c. conditions)
else
    f_x_fun = Function('f_x_fun',{x,z},{f_x,f_q});
    g_lp_fun = Function('g_lp_fun',{x,z},{g_lp}); % lp kkt conditions without bilinear complementarity term (it is treated with the other c.c. conditions)
end

J_cc_fun = Function('J_cc_fun',{z},{f_comp_residual});
f_q_T_fun = Function('f_q_T',{x},{f_q_T});

%% Intigal guess for state derivatives at stage points
if isequal(irk_representation,'differential')
    if simple_v0_guess
        v0 = zeros(n_x,1);
    else
        if n_u>0
            [v0,~] = (f_x_fun(x0,z0,u0));
            v0 = full(v0);
        else
            [v0,~] = (f_x_fun(x0,z0));
            v0 = full(v0);
        end
    end
    model.v0 = v0;
end

%% Collect Outputs
model.sigma = sigma;
model.p = p;
% 
model.lbx = lbx;
model.ubx = ubx;

model.lbu = lbu;
model.ubu = ubu;
if n_u > 0
    model.u0 = u0;
end

if g_ineq_constraint
    model.g_ineq_lb = g_ineq_lb;
    model.g_ineq_ub = g_ineq_ub;
    model.g_ineq_fun = g_ineq_fun;
    model.g_ineq_constraint = g_ineq_constraint;
end

if terminal_constraint
    model.g_terminal_lb = g_terminal_lb;
    model.g_terminal_ub = g_terminal_ub;
    model.terminal_constraint = terminal_constraint;
    model.g_terminal_fun = g_terminal_fun;
end


model.f_x = f_x;
model.f_q = f_q;
model.g_z = g_z;
model.g_lp = g_lp;
model.f_q_T = f_q_T;

model.f_x_fun = f_x_fun;
model.g_lp_fun = g_lp_fun;
model.f_q_T_fun = f_q_T_fun;

model.J_cc_fun = J_cc_fun;
model.g_ind_all_fun = g_ind_all_fun;
model.c_fun = c_fun;
% 
% % Model Dimensions;
model.n_x = n_x;
model.n_z = n_z;
model.n_u = n_u;
model.n_p = n_p;
model.n_simplex = n_simplex;

model.z = z;
model.e_alpha = e_alpha;

model.m_vec = m_vec;
model.m_ind_vec = m_ind_vec;
model.n_theta = n_theta;
model.n_lambda = n_lambda;
model.n_algebraic_constraints = n_algebraic_constraints;
model.n_lift_eq  = n_lift_eq;

model.n_c_vec = n_c_vec;
model.n_alpha = n_alpha;
model.n_beta = n_beta;
model.n_gamma = n_gamma;
model.n_lambda_0 = n_lambda_0;
model.n_lambda_1 = n_lambda_1;


%% collect all dimensions in one sperate struct as it is needed by several other functions later.
dimensions.N_stages = N_stages;
dimensions.N_finite_elements = N_finite_elements;
dimensions.n_x = n_x;
dimensions.n_f = n_f;
dimensions.n_u = n_u;
dimensions.n_z = n_z;
dimensions.n_s = n_s;
dimensions.n_theta = n_theta;
dimensions.n_simplex = n_simplex;
dimensions.m_vec = m_vec;
dimensions.m_ind_vec = m_ind_vec;
dimensions.n_c_vec = n_c_vec;
dimensions.n_alpha = n_alpha;
dimensions.n_beta = n_beta;
dimensions.n_gamma = n_gamma;
dimensions.n_lambda_0 = n_lambda_0;
dimensions.n_lambda_1 = n_lambda_1;

model.dimensions = dimensions;
end
