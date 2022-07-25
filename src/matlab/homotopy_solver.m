function [varargout] = homotopy_solver(solver,model,settings,solver_initalization)
import casadi.*

%%  unfold data
unfold_struct(settings,'caller')
unfold_struct(solver_initalization,'caller')
p_val = model.p_val;

comp_res = model.comp_res;
nabla_J_fun = model.nabla_J_fun;
s_elastic_iter = 1;

sigma_k = sigma_0;
x0 = model.x0;
try
    complementarity_stats = [full(comp_res(w0))];
catch
    w0 = w0(1:length(model.w));
    complementarity_stats = [full(comp_res(w0))];
end
cpu_time = [];
homotopy_iterations = [];
w0_base = w0;

if store_all_homotopy_iterates
    W = [w0];
end

lbw_h = lbw; ubw_h = ubw;
lbw_h(model.ind_h) = model.h_k(1);
ubw_h(model.ind_h) = model.h_k(1);

%% homtopy loop
complementarity_iter = 1;
ii = 0;
vf_resiudal = 0;




while (complementarity_iter+vf_resiudal) > comp_tol && ii < N_homotopy
    % homotopy parameter update
    if ii == 0
        sigma_k = sigma_0;
    else
        sigma_k = kappa*sigma_k;
    end
    p_val(1) = sigma_k;


    % do an nlp solve with only kinematics
    if virtual_forces_kinematic_iteration && ii ==0
        if virtual_forces_convex_combination
            ubw_kin = ubw; ubw_kin(model.ind_vf) = 1;
            lbw_kin = lbw; lbw_kin(model.ind_vf) = 1;
            tic
            results = solver('x0', w0, 'lbx', lbw_kin, 'ubx', ubw_kin,'lbg', lbg, 'ubg', ubg,'p',p_val);
            cpu_time_iter = toc;
            w0 = full(results.x);
            complementarity_iter = full(comp_res(w0));
            vf_resiudal = full(model.J_virtual_froces_fun(w0));
            if print_level >= 3
                fprintf('-----------------------------------------------------------------------------------------------\n');
                fprintf('Solved problem with kinematic model.\n');
                fprintf('Homotopy iteration : %d / %d, with sigma = %2.2e completed.\n',ii,N_homotopy,sigma_k);
                fprintf('Complementarity resiudal: %2.2e.\n',complementarity_iter);
                fprintf('CPU time of iteration: %2.2f s.\n',cpu_time_iter);
                fprintf('Objective function value: %2.4e.\n',cpu_time_iter);
                if virtual_forces
                    fprintf('Virtual forces residual: %2.2e.\n',vf_resiudal);
                end
            else
                fprintf('CPU time of iteration: %2.2f s.\n',cpu_time_iter);
            end
            fprintf('-----------------------------------------------------------------------------------------------\n');
        end
    end
% end

% solve problem with fixed step size
if h_fixed_iterations && use_fesd  && ii < h_fixed_max_iter
    tic
    results = solver('x0', w0, 'lbx', lbw_h, 'ubx', ubw_h,'lbg', lbg, 'ubg', ubg,'p',p_val);
    cpu_time_iter = toc ;
    w_opt = full(results.x);
    if ~h_fixed_change_sigma
        ii = -1; h_fixed_iterations  = 0;
    end
else
    tic
    results = solver('x0', w0, 'lbx', lbw, 'ubx', ubw,'lbg', lbg, 'ubg', ubg,'p',p_val);
    cpu_time_iter = toc ;
end
cpu_time = [cpu_time,cpu_time_iter];

w_opt = full(results.x);
w0 = w_opt;
if store_all_homotopy_iterates
    W = [W,w_opt];
end
% complementarity
complementarity_iter = full(comp_res(w_opt));
complementarity_stats = [complementarity_stats;complementarity_iter];
if virtual_forces
    vf_resiudal = full(model.J_virtual_froces_fun(w_opt));
end
% update counter
ii = ii+1;

% Verbose
if print_level>=3
    fprintf('-----------------------------------------------------------------------------------------------\n');
    fprintf('Homotopy iteration : %d / %d, with sigma = %2.2e completed.\n',ii,N_homotopy,sigma_k);
    fprintf('Complementarity resiudal: %2.2e.\n',complementarity_iter);
    if model.n_u >0
        fprintf('CPU time of iteration: %2.2f s.\n',cpu_time_iter);
        fprintf('Objective function value: %2.4e.\n',cpu_time_iter);
        if time_optimal_problem
            fprintf('Final time T_opt: %2.4f.\n',w_opt(model.ind_t_final));
        end
        if virtual_forces
            fprintf('Virtual forces residual: %2.2e.\n',vf_resiudal);
        end
    else
        fprintf('CPU time of iteration: %2.2f s.\n',cpu_time_iter);
    end
    fprintf('-----------------------------------------------------------------------------------------------\n');
end
%
%     if complementarity_iter> 1e1 && ii >= ratio_for_homotopy_stop*N_homotopy
%         error('The homotopy loop is diverging. Try chaning parameters of the homotopy loop or check is the OCP well posed.')
%         break;
%     end
end
%% polish homotopy solution with fixed active set.
if polishing_step
    [results] = polishing_homotopy_solution(model,settings,results,sigma_k);
    %     [results] = polishing_homotopy_solution(model,settings,results,sigma_k,solver,solver_initalization);
    complementarity_iter = results.complementarity_iter;
    complementarity_stats = [complementarity_stats;complementarity_iter];
    if store_all_homotopy_iterates
        W = [W,results.w_opt];
    end
end

%% save states
stats.complementarity_stats = complementarity_stats;
stats.cpu_time = cpu_time;
stats.cpu_time_total = sum(cpu_time);
% stats.w_opt = w_opt;
stats.sigma_k = sigma_k;
stats.homotopy_iterations = ii;
if store_all_homotopy_iterates
    results.W = W;
end
%% loop output
varargout{1} = results;
varargout{2} = stats;
varargout{3} = solver_initalization;
end

