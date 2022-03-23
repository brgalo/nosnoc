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
clear all
clc
close all

import casadi.*
%%
scenario_name = 'irk_fesd';
save_results = 0;
use_fesd = 0;
%% Benchmark settings
% discretization settings
N_stages  = 3;
N_finite_elements = 1;
n_s_vec = [1 2 3 4 5];
n_s_vec = [2 3];

%% Experiment Set Up
% preproces of step-size  %to avoid exact switch detection by hitting the switch exactly with the given grid
T = 2;
ts = 1; % eact switching time
N_start = 11;
N_end = 2001;
N_samples = 10;

N_start = 11;
N_end = 100;
N_samples = 3;

N_sim_vec = round(logspace(log10(N_start),log10(N_end),N_samples));
N_sim_vec = round(N_sim_vec);
% make all number odd
N_sim_vec(mod(N_sim_vec,2)==0) = N_sim_vec(mod(N_sim_vec,2)==0)+1;
% vector with nonminal step sizes of "outer ingeration steps"
h_sim_vec = T./N_sim_vec;
% length of fintie elements
h_i = h_sim_vec/(N_finite_elements*N_stages);
% number of finite elements until switching point
Ns = ts./h_i;
% sanity check
if any(abs(Ns - round(Ns)) == 0)
    error('exact switch detection just by chance');
end

legend_str = {'Implicit Euler','IRK Radau 3','IRK Radau 5','IRK Radau 7','IRK Radau 9','IRK Radau 11','IRK Radau 13'};
% legend_str = {'IRK GL-2','IRK GL-3','IRK GL-4','IRK GL-5','IRK GL-6','IRK GL-7','IRK GL-8'};
legend_str = [legend_str(n_s_vec)];

%% settings
% collocation settings
settings = default_settings_fesd();
settings.collocation_scheme = 'radau';     % Collocation scheme: radau or legendre
settings.mpcc_mode = 3;
settings.s_elastic_max = 1e1;              % upper bound for elastic variables
% Penalty/Relaxation paraemetr
comp_tol = 1e-16;
settings.comp_tol = comp_tol;
settings.sigma_0 = 1e0;                     % starting smouothing parameter
settings.sigma_N = 1e-15;                     % starting smouothing parameter
settings.N_homotopy = 15 ;% number of steps
settings.kappa = 0.05;                      % decrease rate
%^ IPOPT Settings
opts_ipopt.verbose = false;
opts_ipopt.ipopt.max_iter = 800;
opts_ipopt.ipopt.tol = comp_tol ;
opts_ipopt.ipopt.print_level = 0;
opts_ipopt.ipopt.honor_original_bounds = 'yes';
opts_ipopt.ipopt.bound_relax_factor = 1e-16;
settings.opts_ipopt = opts_ipopt;
% finite elements with switch detection
settings.use_fesd = use_fesd;       % turn on moving finite elements algortihm
settings.fesd_complementartiy_mode = 3;       % turn on moving finite elements algortihm
settings.gamma_h = 1;
settings.equidistant_control_grid = 0;
%% Time settings
omega = 2*pi;
% analytic solution
x_star = [exp(1);0];
s_star = [exp(2)  0; exp(2)*2*omega exp(2)];
t1_star = 1; % optimal siwtch points
T = 2;                            % time budget of transformed pseudo time
T_sim = T;
model.N_stages = N_stages;
model.N_finite_elements = N_finite_elements;
%% for results storing
errors_all_experiments = [];
errors_switch_detection_1_all_experiments = [];
errors_switch_detection_2_all_experiments = [];
complementarity_all_experiments = [];
nominal_h_all_experiments = [];
M_true_all_experiment  = [];

%% Run experiment
h_opt_full = [];
for i = 1:length(n_s_vec)
    n_s = n_s_vec(i);
    n_col = N_stages*(n_s+1); % number of collocation points per 2 finite elements
    settings.n_s = n_s; % update collocation order
    % store data for fixed d and variable M/h
    errors_current_experiment = [];
    complementarity_current_experiment = [];
    nominal_h_current_experiment = [];
    M_true_current_experiment  = [];

    for  j = 1:length(N_sim_vec)
        h_outside = h_sim_vec(j); % integrator step of FESD (outside step length)
        N_sim = T_sim/h_outside;
        h_inside = h_outside/(N_finite_elements);    % nominal step lenght of a single finite elemnt;
        h = h_inside;
        M_true_current = N_sim*n_col;
        M = M_true_current;
        % update step size
        model.T = h_outside;
        model.T_sim = h_outside;
        model.h = h_inside/N_stages;
        model.N_sim = N_sim;
        fprintf('Scheme with d = %d, current collocattion points %d , run: %d of %d \n',n_s,M_true_current,j,length(N_sim_vec))
        % generate new model with updated settings;
        model = oscilator(model);
        [results,stats] = integrator_fesd(model,settings);

        % numerical error
        x_fesd = results.x_res(:,end);
        error_x = norm(x_fesd-x_star,"inf");
        max_complementarity_exp = max(stats.complementarity_stats);

        errors_current_experiment = [errors_current_experiment,error_x];
        fprintf('Error with (h = %2.5f, M = %d, d = %d ) is %5.2e : \n',h,M,n_s,error_x);
        fprintf('Complementarity residual %5.2e : \n',max_complementarity_exp);
        % save date current experiemnt
        complementarity_current_experiment = [complementarity_current_experiment,max_complementarity_exp];
        nominal_h_current_experiment = [nominal_h_current_experiment,h];
        M_true_current_experiment = [M_true_current_experiment,M_true_current];
    end
    errors_all_experiments = [errors_all_experiments;errors_current_experiment];
    nominal_h_all_experiments = [nominal_h_all_experiments;nominal_h_current_experiment];
    M_true_all_experiment = [M_true_all_experiment;M_true_current_experiment];
    complementarity_all_experiments = [complementarity_all_experiments;complementarity_current_experiment];
end

%% Error plots
figure
for ii = 1:length(n_s_vec)
    loglog(M_true_all_experiment(ii,:),errors_all_experiments(ii,:),'-o','linewidth',1.5);
    hold on
end
xlabel('$M$','interpreter','latex');
ylabel('$E(2)$','interpreter','latex');
grid on
ylim([1e-14 100])
legend(legend_str,'interpreter','latex');
if save_results
    saveas(gcf,[scenario_name '_error_M'])
end
% some stats
if length(N_sim_vec) == 1
    figure
    subplot(211)
    stairs(stats.homotopy_iteration_stats)
    xlabel('$N$','interpreter','latex');
    ylabel('homotopy iterations','interpreter','latex');
    grid on
    subplot(212)
    semilogy(stats.complementarity_stats+1e-20,'k.-')
    xlabel('$N$','interpreter','latex');
    ylabel('comp residual','interpreter','latex');
    grid on
end
% complementarity residual
figure
loglog(M_vec,complementarity_all_experiments+1e-18,'-o','linewidth',1.5);
hold on
xlabel('$M$','interpreter','latex');
ylabel('comp residual','interpreter','latex');
grid on
legend(legend_str,'interpreter','latex');
if save_results
    saveas(gcf,[scenario_name '_comp_residual_M'])
end
% error as fu
figure
for ii = 1:length(n_s_vec)
    loglog(nominal_h_all_experiments(ii,:),complementarity_all_experiments(ii,:)+1e-18,'-o','linewidth',1.5);
    hold on
end
xlabel('$h$','interpreter','latex');
ylabel('comp residual','interpreter','latex');
grid on
legend(legend_str,'interpreter','latex');
if save_results
    saveas(gcf,[scenario_name '_comp_residual_h'])
end
%% as function of step size
figure
for ii = 1:length(n_s_vec)
    loglog(nominal_h_all_experiments(ii,:),errors_all_experiments(ii,:),'-o','linewidth',1.5);
    hold on
    xlabel('$h$','interpreter','latex');
    ylabel('$E(2)$','interpreter','latex');
    grid on
end
ylim([1e-14 100])
legend(legend_str,'interpreter','latex');
if save_results
    saveas(gcf,[scenario_name '_error_h'])
end


%% Practial slopes
if length(M_vec) ==1
    fprintf('Error: %5.2e, h = %4.4f \n',errors_all_experiments,h)
end

%%
results.M_vec = M_vec;
results.d_vec = n_s_vec;
results.M_true_all_experiment =M_true_all_experiment;
results.errors_switch_detection_1_all_experiments =errors_switch_detection_1_all_experiments;
results.nominal_h_all_experiments =nominal_h_all_experiments;
results.errors_all_experiments =errors_all_experiments;
results.complementarity_all_experiments = complementarity_all_experiments;
if save_results
    save([scenario_name '.mat'],'results')
end