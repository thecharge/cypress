require 'test_helper'
# rubocop:disable Metrics/ClassLength
class C2TaskTest < MiniTest::Test
  include ::Validators
  include ActiveJob::TestHelper

  def setup
    collection_fixtures('product_tests', 'products', 'bundles',
                        'measures', 'records', 'patient_cache')
    @product_test = ProductTest.find('51703a6a3054cf8439000044')
  end

  def after_teardown
    clear_enqueued_jobs
    drop_database
  end

  def test_create
    assert @product_test.tasks.create({}, C2Task)
  end

  def test_should_exclude_c3_validators_when_no_c3
    @product_test.tasks.clear
    task = @product_test.tasks.create({}, C2Task)
    assert !@product_test.contains_c3_task?

    task.validators.each do |v|
      assert !v.is_a?(MeasurePeriodValidator)
    end
  end

  def test_should_include_c3_validators_when_c3_exists
    task = @product_test.tasks.create({}, C2Task)
    @product_test.tasks.create({}, C3Task)

    assert @product_test.contains_c3_task?
    assert task.validators.count { |v| v.is_a?(MeasurePeriodValidator) } > 0
  end

  def test_execute
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_good.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      assert te.execution_errors.empty?, 'should be no errors for good cat I archive'
    end
  end

  def test_should_not_error_when_measure_period_is_wrong_without_c3
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_bad_mp.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      assert_equal 0, te.execution_errors.length, 'should have no errors for the invalid reporting period'
    end
  end

  def test_should_error_when_measure_period_is_wrong
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    ptest.tasks.create({}, C3Task)
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_bad_mp.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      assert_equal 2, te.execution_errors.length, 'should have 2 errors for the invalid reporting period'
    end
  end

  def test_should_cause_error_when_stratifications_are_missing
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_missing_stratification.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # Missing strat for the 1 numerator that has data
      assert_equal 1, te.execution_errors.length, 'should error on missing stratifications'
    end
  end

  def test_should_cause_error_when_supplemental_data_is_missing
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_missing_supplemental.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # checked 3 times for each numerator -- we should do something about that
      assert_equal 3, te.execution_errors.length, 'should error on missing supplemetnal data'
    end
  end

  def test_should_cause_error_when_not_all_populations_are_accounted_for
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_missing_stratification.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      assert_equal 1, te.execution_errors.length, 'should error on missing populations'
    end
  end

  def test_should_cause_error_when_the_schema_structure_is_bad
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_bad_schematron.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # 3 errors 1 for schema validation and 2 schematron issues for realmcode
      assert_equal 3, te.execution_errors.length, 'should error on bad schematron'
    end
  end

  def test_should_cause_error_when_measure_is_not_included_in_report
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_missing_measure.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # 9 is for all of the sub measures to be searched for
      # 2 for missing supplemental data
      assert_equal 21, te.execution_errors.length, 'should error on missing measure entry'
    end
  end

  def test_should_cause_error_when_measure_is_not_included_in_report_with_c3
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    ptest.tasks.create({}, C3Task)
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_missing_measure.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # 9 is for all of the sub measures to be searched for
      # 2 is for having incorrect measure Ids
      # 2 for missing supplemental data
      assert_equal 23, te.execution_errors.length, 'should error on missing measure entry'
    end
  end

  def test_should_cause_error_when_extra_supplemental_data_is_provided
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_extra_supplemental.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      # 1 Error for additional Race
      assert_equal 1, te.execution_errors.length, 'should error on additional supplemental data'
    end
  end

  def test_should_not_cause_error_when_extra_supplemental_data_provided_has_zero_value
    ptest = ProductTest.find('51703a6a3054cf8439000044')
    task = ptest.tasks.create({ expected_results: ptest.expected_results }, C2Task)
    xml = create_rack_test_file('test/fixtures/qrda/ep_test_qrda_cat3_extra_supplemental_is_zero.xml', 'application/xml')
    perform_enqueued_jobs do
      te = task.execute(xml)
      te.reload
      assert te.execution_errors.empty?, 'should not error on additional supplemental data value equal to 0'
    end
  end
end
