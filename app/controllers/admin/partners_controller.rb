# frozen_string_literal: true

module Admin
  class PartnersController < BaseController
    PARTNER_PAGE_SIZE = 10

    before_action :set_partner, only: %i[show edit update destroy]

    def index
      @query = params[:q].to_s.strip
      load_partners
      @partner = Partner.new

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append(
              'partners_rows',
              partial: 'admin/partners/partner_row',
              collection: @partners,
              as: :partner,
              locals: { query: @query, row_offset: @row_offset }
            ),
            turbo_stream.replace(
              'partners_pagination',
              partial: 'admin/partners/partners_pagination',
              locals: { query: @query, next_page: @next_page }
            )
          ]
        end
      end
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
        if from_modal?
          load_partners
          @open_partner_modal = true
          flash.now[:alert] = @partner.errors.full_messages

          respond_to do |format|
            format.html { render :index, status: :unprocessable_entity }
            format.turbo_stream { render_flash_turbo_stream(status: :unprocessable_entity) }
          end
        else
          flash.now[:alert] = @partner.errors.full_messages
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit; end

    def update
      if @partner.update(partner_params)
        respond_to do |format|
          format.html do
            if from_inline?
              redirect_to admin_partners_path, notice: 'Cập nhật đối tác thành công.'
            else
              redirect_to admin_partner_path(@partner), notice: 'Cập nhật đối tác thành công.'
            end
          end

          format.turbo_stream do
            if from_inline?
              @query = params[:q].to_s.strip
              load_partners
              @partner = Partner.new
              flash.now[:notice] = 'Cập nhật đối tác thành công.'
              render_partners_turbo_stream
            else
              redirect_to admin_partner_path(@partner), notice: 'Cập nhật đối tác thành công.'
            end
          end
        end
      else
        respond_to do |format|
          format.html do
            if from_inline?
              redirect_to admin_partners_path, alert: @partner.errors.full_messages
            else
              flash.now[:alert] = @partner.errors.full_messages
              render :edit, status: :unprocessable_entity
            end
          end

          format.turbo_stream do
            if from_inline?
              error_message = @partner.errors.full_messages
              @query = params[:q].to_s.strip
              load_partners
              @partner = Partner.new
              flash.now[:alert] = error_message
              render_partners_turbo_stream(status: :unprocessable_entity)
            else
              flash.now[:alert] = @partner.errors.full_messages
              render :edit, status: :unprocessable_entity
            end
          end
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
      partners = Partner.order(:name, :id)
      if @query.present?
        partners = partners.where('name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
      end

      @page = [params[:page].to_i, 1].max
      @row_offset = (@page - 1) * PARTNER_PAGE_SIZE
      @partners = partners.offset(@row_offset).limit(PARTNER_PAGE_SIZE).to_a
      @next_page = partners.offset(@row_offset + PARTNER_PAGE_SIZE).limit(1).exists? ? @page + 1 : nil
    end

    def partner_params
      params.expect(partner: [ :name ])
    end

    def from_modal?
      params[:from_modal] == '1'
    end

    def from_inline?
      params[:from_inline] == '1'
    end

    def render_partners_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace(
          'admin_partners_page',
          partial: 'admin/partners/page'
        ),
        turbo_stream.update(
          'flash_container',
          partial: 'shared/flash',
          locals: { flash: flash }
        )
      ], status: status
    end

    def render_flash_turbo_stream(status: :ok)
      render turbo_stream: turbo_stream.update(
        'flash_container',
        partial: 'shared/flash',
        locals: { flash: flash }
      ), status: status
    end
  end
end
