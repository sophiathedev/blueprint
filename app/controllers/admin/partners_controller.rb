# frozen_string_literal: true

module Admin
  class PartnersController < BaseController
    before_action :set_partner, only: %i[show edit update destroy]

    def index
      @query = params[:q].to_s.strip
      load_partners
      @partner = Partner.new
    end

    def show; end

    def new
      @partner = Partner.new
    end

    def create
      @partner = Partner.new(partner_params)

      if @partner.save
        redirect_to admin_partners_path, notice: 'Tạo đối tác thành công.'
      else
        flash.now[:alert] = @partner.errors.full_messages.to_sentence

        if from_modal?
          load_partners
          @open_partner_modal = true
          render :index, status: :unprocessable_entity
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit; end

    def update
      if @partner.update(partner_params)
        if from_inline?
          redirect_to admin_partners_path, notice: 'Cập nhật đối tác thành công.'
        else
          redirect_to admin_partner_path(@partner), notice: 'Cập nhật đối tác thành công.'
        end
      else
        if from_inline?
          redirect_to admin_partners_path, alert: @partner.errors.full_messages.to_sentence
        else
          flash.now[:alert] = @partner.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @partner.destroy
      redirect_to admin_partners_path, notice: 'Xóa đối tác thành công.'
    end

    private

    def set_partner
      @partner = Partner.find(params[:id])
    end

    def load_partners
      @partners = Partner.order(:name, :id)
      return if @query.blank?

      @partners = @partners.where('name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
    end

    def partner_params
      params.expect(partner: [:name])
    end

    def from_modal?
      params[:from_modal] == '1'
    end

    def from_inline?
      params[:from_inline] == '1'
    end
  end
end
