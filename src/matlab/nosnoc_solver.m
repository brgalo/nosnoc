%
%    This file is part of NOS-NOC.
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
%% Possible outputs
% [results]= nosnoc_solver(model,settings);
% [results,stats] = nosnoc_solver(model,settings);
% [results,stats,model] = nosnoc_solver(model,settings);
% [results,stats,model,settings] = nosnoc_solver(model,settings);
% [results,stats,model,settings,solver_initalization] = nosnoc_solver(model,settings);
function [varargout] = nosnoc_solver(model,settings)
import casadi.*
%% load data

%% Create NLP element and solve OCP with homotopy
[solver,solver_initalization, model,settings] = create_nlp_fesd(model,settings);
[results,stats,solver_initalization] = homotopy_solver(solver,model,settings,solver_initalization);

total_time = sum(stats.cpu_time);

%% Process and store results
unfold_struct(settings,'caller')
unfold_struct(model,'caller')
% Store differentail states
w_opt = full(results.x);
diff_states = w_opt(ind_x);
alg_states = w_opt(ind_z);

u_opt = w_opt(ind_u);
u_opt = reshape(u_opt,n_u,N_stages);

if use_fesd 
    h_opt = w_opt(ind_h);
else
    h_opt  = h*ones(sum(N_finite_elements),1);
end


x_opt_extended = w_opt(ind_x);
x_opt_extended  = reshape(x_opt_extended,n_x,length(x_opt_extended)/n_x);
x_opt  = x_opt_extended(:,1:n_s+1:end);

alg_states_extended = reshape(alg_states,n_z,length(alg_states)/n_z);
theta_opt_extended = [alg_states_extended(1:n_theta*n_simplex,:)];
lambda_opt_extended = [alg_states_extended(n_theta*n_simplex+1:2*n_theta*n_simplex,:)];
mu_opt_extended = [alg_states_extended(end-n_simplex+1:end,:)];


theta_opt= theta_opt_extended(:,1:n_s+1:end);
lambda_opt= lambda_opt_extended(:,1:n_s+1:end);
mu_opt= mu_opt_extended(:,1:n_s+1:end);

t_grid = cumsum([0;h_opt]);

if time_optimal_problem
    T_opt = w_opt(ind_t_final);
else
    T_opt = [];
end

%% Adapt the grid in case of time optimal problems
if time_optimal_problem
    if use_speed_of_time_variables
        s_sot = w_opt(ind_sot);
        if ~local_speed_of_time_variable    
            s_sot = s_sot*ones(N_stages,1);
        end
        h_rescaled = [];
        ind_prev = 1;
        for ii = 1:N_stages
            h_rescaled = [h_rescaled;h_opt(ind_prev:N_finite_elements(ii)+ind_prev-1).*s_sot(ii)];
            ind_prev = ind_prev+N_finite_elements(ii);
        end
        t_grid = cumsum([0;h_rescaled]);
    else
        t_grid = cumsum([0;h_opt]);
    end
end

%% Verbose
fprintf('\n');
fprintf('-----------------------------------------------------------------------------------------------\n');
if use_fesd
    fprintf( ['OCP with the FESD ' irk_scheme ' in ' irk_representation ' mode with %d stages completed in %2.3f s.\n'],n_s,total_time);
else
    fprintf( ['OCP with the ' irk_scheme ' scheme with %d stages completed in %2.3f s.\n'],n_s,total_time);
end
fprintf('Total homotopy solver time: %2.3f seconds with %d homotopy iterations.\n',sum(stats.cpu_time),length(stats.cpu_time));
fprintf('Max iteration time: %2.3f seconds, min iteration time: %2.3f seconds.\n',max(stats.cpu_time),min(stats.cpu_time));
fprintf('Complementarity residual: %2.3e.\n',max(stats.complementarity_stats(end)));
fprintf('-----------------------------------------------------------------------------------------------\n\n');

%%

stats.total_time  = total_time;

results.x_opt = x_opt;
results.x_opt_extended = x_opt_extended;

results.t_grid = t_grid;

ind_t_grid_u = cumsum([1; N_finite_elements]);
results.t_grid_u = t_grid(ind_t_grid_u); 
results.theta_opt = theta_opt;
results.lambda_opt = lambda_opt;
results.mu_opt = mu_opt;

results.theta_opt_extended = theta_opt_extended;
results.lambda_opt_extended = lambda_opt_extended;
results.mu_opt_extended = mu_opt_extended;

results.u_opt = u_opt;
results.f_opt = full(results.f);
results.f = [];
results.T_opt = T_opt;
results.w_opt = w_opt;
%% Output
varargout{1} = results;
varargout{2} = stats;
varargout{3} = model;
varargout{4} = settings;
varargout{5} = solver_initalization;
end



