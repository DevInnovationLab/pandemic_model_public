function tests = run_regression_test
    % Regression test: run the reference workflow and compare outputs to
    % committed reference files in tests/reference/.
    %
    % Usage (from MATLAB GUI or batch):
    %   run('./matlab/load_project')
    %   results = runtests('matlab/tests/run_regression_test.m')
    %
    % Prerequisites:
    %   1. Reference outputs must exist in tests/reference/allrisk_base_small/.
    %      See tests/reference/README.md for generation instructions.
    %   2. The model must be able to run locally without SLURM (single chunk).
    %
    % This test produces a fresh run of allrisk_base_small.yaml into a
    % temporary output directory, then compares processed/ .mat files to
    % the reference outputs field-by-field using isequal (exact match).
    % Any discrepancy indicates a change to computed results.

    tests = functiontests(localfunctions);
end


function setup(testCase)
    repo_root = get_repo_root();
    tmp_outdir = fullfile(tempdir, 'pandemic_model_regression_test');
    if isfolder(tmp_outdir)
        rmdir(tmp_outdir, 's');
    end
    mkdir(tmp_outdir);
    testCase.TestData.repo_root = repo_root;
    testCase.TestData.tmp_outdir = tmp_outdir;
end


function teardown(testCase)
    if isfolder(testCase.TestData.tmp_outdir)
        rmdir(testCase.TestData.tmp_outdir, 's');
    end
end


function test_baseline_annual_sums_match_reference(testCase)
    % Run workflow and compare baseline_annual_sums.mat to reference.
    repo_root = testCase.TestData.repo_root;
    tmp_outdir = testCase.TestData.tmp_outdir;

    config_path = fullfile(repo_root, 'config', 'job_configs', 'allrisk_base_small.yaml');
    run_workflow(config_path, 'sim_results_path', fullfile(tmp_outdir, 'allrisk_base_small'));

    new_file = fullfile(tmp_outdir, 'allrisk_base_small', 'processed', 'baseline_annual_sums.mat');
    ref_file = fullfile(repo_root, 'tests', 'reference', 'allrisk_base_small', 'processed', 'baseline_annual_sums.mat');

    assert_mat_files_equal(testCase, new_file, ref_file, 'baseline_annual_sums');
end


function test_scenario_relative_sums_match_reference(testCase)
    % Compare each scenario's _relative_sums.mat to reference.
    repo_root = testCase.TestData.repo_root;
    tmp_outdir = testCase.TestData.tmp_outdir;

    processed_dir = fullfile(tmp_outdir, 'allrisk_base_small', 'processed');
    ref_processed_dir = fullfile(repo_root, 'tests', 'reference', 'allrisk_base_small', 'processed');

    sums_files = dir(fullfile(processed_dir, '*_relative_sums.mat'));
    testCase.assertGreaterThan(numel(sums_files), 0, ...
        'No _relative_sums.mat files found in processed/. Run test_baseline_annual_sums_match_reference first.');

    for k = 1:numel(sums_files)
        fname = sums_files(k).name;
        new_file = fullfile(processed_dir, fname);
        ref_file = fullfile(ref_processed_dir, fname);
        assert_mat_files_equal(testCase, new_file, ref_file, fname);
    end
end


% -------------------------------------------------------------------------
% Helpers
% -------------------------------------------------------------------------

function assert_mat_files_equal(testCase, new_file, ref_file, label)
    testCase.assertTrue(isfile(ref_file), ...
        sprintf('Reference file missing: %s\nSee tests/reference/README.md to generate it.', ref_file));
    testCase.assertTrue(isfile(new_file), ...
        sprintf('New output file missing: %s', new_file));

    new_data = load(new_file);
    ref_data = load(ref_file);

    new_fields = fieldnames(new_data);
    ref_fields = fieldnames(ref_data);

    testCase.assertEqual(sort(new_fields), sort(ref_fields), ...
        sprintf('%s: field names differ between new and reference output.', label));

    for i = 1:numel(ref_fields)
        f = ref_fields{i};
        testCase.assertTrue(isequal(new_data.(f), ref_data.(f)), ...
            sprintf('%s: field "%s" does not match reference. Results have changed.', label, f));
    end
end


function repo_root = get_repo_root()
    this_file = mfilename('fullpath');             % .../matlab/tests/run_regression_test
    matlab_dir = fileparts(this_file);            % .../matlab/tests
    repo_root = fileparts(fileparts(matlab_dir)); % repo root
end
