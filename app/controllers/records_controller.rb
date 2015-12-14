class RecordsController < ApplicationController
  before_action :set_record_source, only: [:index]

  def download_full_test_deck
    product = Product.find(params[:id])
    file = Cypress::CreateDownloadZip.create_total_test_zip(product)
    send_data file.read, type: 'application/zip', disposition: 'attachment', filename: "Full_Test_Deck_#{product.id}.zip"
  end

  def index
    @records = @source.records
  end

  def show
    @record = Record.find(params[:id])
  end

  private

  def set_record_source
    if params[:bundle_id]
      @bundle = Bundle.find(params[:bundle_id])
      @source = @bundle
    elsif params[:product_test_id]
      @product_test = ProductTest.find(params[:product_test_id])
      @source = @product_test
    elsif params[:task_id]
      @task = Task.find(params[:task_id])
      @source = @task
    else
      @bundle = Bundle.first
      @source = @bundle
    end
  end
end
