clc
N_stages_vec = [10:5:80];
N_trails = 1;
minlp_time_limit = 600;
experiment_names = {'fesd','std','gurobi','bonmin'};
legend_str = {'NOSNOC-FESD','NOSNOC-Std','Gurobi','Bonmin'};

run_fesd = 0; run_std = 0;
run_gurobi = 0; run_bonmin = 1;
run_experiments = [run_fesd run_std run_gurobi run_bonmin];
%% NOSNOC settings
[settings] = default_settings_fesd();  % Optionally call this function to have an overview of all options. Missing settings are anyway filled in latter with their respecitve values.
settings.N_trails = N_trails;
settings.sigma_0 = 10;
% settings.N_homotopy = 20;
settings.print_level = 0;
settings.mpcc_mode = 3;
settings.use_fesd = 1;
settings.comp_tol = 1e-12;
settings.time_optimal_problem = 1;
settings.n_s = 2;
% model data
model.N_finite_elements = 3;
model.T = 1;

%% results
% time
cpu_time_fesd = []; cpu_time_all_fesd = [];
cpu_time_std = []; cpu_time_all_std = [];
cpu_time_gurobi = []; cpu_time_all_gurobi = [];
cpu_time_bonmin = []; cpu_time_all_bonmin= [];
% error
error_fesd = []; error_all_fesd = [];
error_std = []; error_all_std = [];
error_gurobi = []; error_all_gurobi = [];
error_bonmin = []; error_all_bonmin = [];
% objective
T_opt_fesd = [];
T_opt_std = [];
T_opt_gurobi = [];
T_opt_bonmin = [];
%%  run nosnoc with fesd
if run_fesd
    for ii = 1:length(N_stages_vec)
        model.N_stages = N_stages_vec(ii);
        output = solve_car_turbo_with_nosnoc(model,settings);
        cpu_time_fesd  = [cpu_time_fesd, output.cpu_time];
        cpu_time_all_fesd  = [cpu_time_all_fesd , output.cpu_time_all'];
        T_opt_fesd  = [T_opt_fesd  , output.T_opt  ];
        error_fesd = [error_fesd, output.error];
        error_all_fesd = [error_all_fesd, output.error_all];
    end

    % collect output
    output_fesd.cpu_time_fesd = cpu_time_fesd;
    output_fesd.cpu_time_all_fesd = cpu_time_all_fesd;
    output_fesd.T_opt_fesd = T_opt_fesd;
    output_fesd.error_fesd = error_fesd;
    output_fesd.error_all_fesd = error_all_fesd;
    % save result
    save(['output_fesd.mat'],'output_fesd')
end
%% run nosnoc with std
if run_std
    settings.use_fesd = 0;
    settings.use_speed_of_time_variables = 1;
    settings.local_speed_of_time_variable = 0;
    settings.mpcc_mode = 3;
    for ii = 1:length(N_stages_vec)
        model.N_stages = N_stages_vec(ii);
        output = solve_car_turbo_with_nosnoc(model,settings);
        cpu_time_std  = [cpu_time_std, output.cpu_time];
        cpu_time_all_std  = [cpu_time_all_std , output.cpu_time_all'];
        T_opt_std  = [T_opt_std  , output.T_opt  ];
        error_std = [error_std, output.error];
        error_all_std = [error_all_std, output.error_all];
    end

    output_std.cpu_time_std = cpu_time_std;
    output_std.cpu_time_all_std = cpu_time_all_std;
    output_std.T_opt_std = T_opt_std;
    output_std.error_std = error_std;
    output_std.error_all_std = error_all_std;
    save(['output_std.mat'],'output_std')
end
%% run gurobi
time_limit_reached = 0;
if run_gurobi
    settings.gurobi_tol = 1e-6;
    for ii = 1:length(N_stages_vec)
        model.N_stages = N_stages_vec(ii);
        output = solve_car_turbo_with_gurobi(model,settings);
        % save
        cpu_time_gurobi  = [cpu_time_gurobi, output.cpu_time];
        cpu_time_all_gurobi  = [cpu_time_all_gurobi , output.cpu_time_all'];
        T_opt_gurobi  = [T_opt_gurobi  , output.T_opt ];
        error_gurobi = [error_gurobi, output.error];
        error_all_gurobi = [error_all_gurobi, output.error_all];
        %check and break
        if output.cpu_time(end) > minlp_time_limit
            fprintf('Time limit reached. \n');
            break;
            time_limit_reached = 1;
        end

    end

%     if time_limit_reached
%         error_gurobi = [error_gurobi,nan*ones(1,length(N_stages_vec)-length(error_gurobi))];
%         error_all_gurobi = [error_all_gurobi,nan*ones(1,length(N_stages_vec)-length(error_all_gurobi))];
%         T_opt_gurobi = [T_opt_gurobi,nan*ones(1,length(N_stages_vec)-length(T_opt_gurobi))];
%         cpu_time_gurobi = [cpu_time_gurobi,nan*ones(1,length(N_stages_vec)-length(cpu_time_gurobi))];
%         cpu_time_all_gurobi = [cpu_time_all_gurobi,nan*ones(N_trails,length(N_stages_vec)-length(cpu_time_all_gurobi))];
%     end
    output_gurobi.cpu_time_gurobi = cpu_time_gurobi;
    output_gurobi.cpu_time_all_gurobi = cpu_time_all_gurobi;
    output_gurobi.T_opt_gurobi = T_opt_gurobi;
    output_gurobi.error_gurobi = error_gurobi;
    output_gurobi.error_all_gurobi = error_all_gurobi;
    save(['output_gurobi.mat'],'output_gurobi')
end
%% run bonbmin
time_limit_reached = 0;
if run_bonmin
    for ii = 1:length(N_stages_vec)
        model.N_stages = N_stages_vec(ii);
        output = solve_car_turbo_with_bonmin(model,settings);
        % save
        cpu_time_bonmin  = [cpu_time_bonmin, output.cpu_time];
        cpu_time_all_bonmin  = [cpu_time_all_bonmin , output.cpu_time_all'];
        T_opt_bonmin  = [T_opt_bonmin  , output.T_opt];
        error_bonmin = [error_bonmin, output.error];
        error_all_bonmin = [error_all_bonmin, output.error_all];
        % check and break
        if output.cpu_time(end) > minlp_time_limit
            fprintf('Time limit reached. \n');
            break;
            time_limit_reached = 1;
        end
    end
%     if time_limit_reached
%         error_bonmin = [error_bonmin,nan*ones(1,length(N_stages_vec)-length(error_bonmin))];
%         error_all_bonmin = [error_all_bonmin,nan*ones(1,length(N_stages_vec)-length(error_all_bonmin))];
%         T_opt_bonmin = [T_opt_bonmin,nan*ones(1,length(N_stages_vec)-length(T_opt_bonmin))];
%         cpu_time_bonmin = [cpu_time_bonmin,nan*ones(1,length(N_stages_vec)-length(cpu_time_bonmin))];
%         cpu_time_all_bonmin = [cpu_time_all_bonmin,nan*ones(N_trails,length(N_stages_vec)-length(cpu_time_all_bonmin))];
%     end
    output_bonmin.cpu_time_bonmin = cpu_time_bonmin;
    output_bonmin.cpu_time_all_bonmin = cpu_time_all_bonmin;
    output_bonmin.T_opt_bonmin = T_opt_bonmin;
    output_bonmin.error_bonmin = error_bonmin;
    output_bonmin.error_all_bonmin = error_all_bonmin;
    % save result
    save(['output_bonmin.mat'],'output_bonmin')
end
%%
fprintf('The benchmark was sucessful. \n')
% cpu_time_bonmin(cpu_time_bonmin ==nan) = 0;
total_time = sum(cpu_time_fesd)+sum(cpu_time_std)+sum(cpu_time_gurobi)+sum(cpu_time_bonmin);
fprintf('Total cpu time %2.2f s;  %2.2f min. \n',total_time,total_time/60)
plot_benchmark_result