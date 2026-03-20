# frozen_string_literal: true

module Admin
  class AllServicesController < BaseController
    SERVICE_PAGE_SIZE = ServicesController::SERVICE_PAGE_SIZE

    before_action :set_service, only: %i[update destroy tasks_panel]

    def index
      @query = params[:q].to_s.strip
      @selected_partner_id = params[:partner_id].to_s.strip
      load_partner_options
      @service = Service.new(partner_id: @selected_partner_id)
      load_services

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append(
              'services_rows',
              partial: 'admin/services/service_row',
              collection: @services,
              as: :service,
              locals: { query: @query, row_offset: @row_offset, show_partner: true, selected_partner_id: @selected_partner_id }
            ),
            turbo_stream.replace(
              'services_pagination',
              partial: 'admin/services/services_pagination',
              locals: { pagination_url: admin_services_path(q: @query, partner_id: @selected_partner_id, page: @next_page, format: :turbo_stream), next_page: @next_page }
            )
          ]
        end
      end
    end

    def create
      @query = params[:q].to_s.strip
      @selected_partner_id = params[:partner_id].to_s.strip
      load_partner_options
      @service = Service.new(service_params)
      @selected_partner_id = @service.partner_id.to_s if @service.partner_id.present?

      if @service.save
        @created_service = @service
        @show_create_task_prompt = true
        @task = @created_service.tasks.build
        @member_options = member_options
        @service = Service.new(partner_id: @selected_partner_id)
        load_services
        flash.now[:notice] = 'Tạo dịch vụ thành công.'

        respond_to do |format|
          format.html do
            redirect_to admin_services_path(partner_id: @selected_partner_id), notice: 'Tạo dịch vụ thành công.'
          end
          format.turbo_stream { render_all_services_turbo_stream }
        end
      else
        load_services
        @open_service_modal = true
        flash.now[:alert] = @service.errors.full_messages

        respond_to do |format|
          format.html { render :index, status: :unprocessable_entity }
          format.turbo_stream { render_all_services_turbo_stream(status: :unprocessable_entity) }
        end
      end
    end

    def update
      @query = params[:q].to_s.strip
      @selected_partner_id = params[:partner_id].to_s.strip
      load_partner_options

      if @service.update(service_params)
        @service = Service.new(partner_id: @selected_partner_id)
        load_services
        flash.now[:notice] = 'Cập nhật dịch vụ thành công.'

        respond_to do |format|
          format.html { redirect_to admin_services_path(q: @query, partner_id: @selected_partner_id), notice: 'Cập nhật dịch vụ thành công.' }
          format.turbo_stream { render_all_services_turbo_stream }
        end
      else
        error_message = @service.errors.full_messages
        @service = Service.new(partner_id: @selected_partner_id)
        load_services
        flash.now[:alert] = error_message

        respond_to do |format|
          format.html { redirect_to admin_services_path(q: @query, partner_id: @selected_partner_id), alert: error_message }
          format.turbo_stream { render_all_services_turbo_stream(status: :unprocessable_entity) }
        end
      end
    end

    def destroy
      @query = params[:q].to_s.strip
      @selected_partner_id = params[:partner_id].to_s.strip
      @service.destroy

      respond_to do |format|
        format.html { redirect_to admin_services_path(q: @query, partner_id: @selected_partner_id), notice: 'Xóa dịch vụ thành công.' }
        format.turbo_stream do
          load_partner_options
          @service = Service.new(partner_id: @selected_partner_id)
          load_services
          flash.now[:notice] = 'Xóa dịch vụ thành công.'
          render_all_services_turbo_stream
        end
      end
    end

    def tasks_panel
      return redirect_to(admin_partner_service_tasks_path(@service.partner, @service)) unless turbo_frame_request?

      @tasks = @service.tasks.order(created_at: :desc).includes(:member)
      @member_options = member_options
      @show_all_tasks = ActiveModel::Type::Boolean.new.cast(params[:show_all])

      render partial: 'admin/services/tasks_panel', locals: {
        partner: @service.partner,
        service: @service,
        tasks: @tasks,
        member_options: @member_options,
        edit_task: nil,
        show_all_tasks: @show_all_tasks
      }
    end

    private

    def set_service
      @service = Service.includes(:partner).find(params[:id])
    end

    def load_partner_options
      @partner_options = Partner.order(:name).pluck(:name, :id).unshift([ 'Tất cả đối tác', '' ])
      @selected_partner = Partner.find_by(id: @selected_partner_id) if @selected_partner_id.present?
    end

    def load_services
      services = Service.includes(:partner).references(:partner).order('services.name ASC', 'services.id ASC')
      if @query.present?
        sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
        services = services.where('services.name ILIKE :query OR partners.name ILIKE :query', query: sanitized_query)
      end
      services = services.where(partner_id: @selected_partner_id) if @selected_partner_id.present?

      @page = [ params[:page].to_i, 1 ].max
      @row_offset = (@page - 1) * SERVICE_PAGE_SIZE
      @services = services.offset(@row_offset).limit(SERVICE_PAGE_SIZE).to_a
      @next_page = services.offset(@row_offset + SERVICE_PAGE_SIZE).limit(1).exists? ? @page + 1 : nil
    end

    def service_params
      params.expect(service: [ :partner_id, :name ])
    end

    def member_options
      User.member.order(created_at: :desc, id: :desc).map do |member|
        [ member.display_name, member.id ]
      end
    end

    def render_flash_turbo_stream(status: :ok)
      render turbo_stream: turbo_stream.prepend(
        'flash_messages',
        partial: 'shared/flash_messages',
        locals: { flash: flash }
      ), status: status
    end

    def render_all_services_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace(
          'services_list_frame',
          partial: 'admin/services/services_list',
          locals: {
            services: @services,
            query: @query,
            filter_active: @query.present? || @selected_partner_id.present?,
            row_offset: @row_offset,
            next_page: @next_page,
            selected_partner_id: @selected_partner_id,
            pagination_url: admin_services_path(q: @query, partner_id: @selected_partner_id, page: @next_page, format: :turbo_stream),
            show_partner: true,
            show_create_button: false
          }
        ),
        turbo_stream.replace(
          'all_services_modals',
          partial: 'admin/all_services/modals'
        ),
        turbo_stream.prepend(
          'flash_messages',
          partial: 'shared/flash_messages',
          locals: { flash: flash }
        )
      ], status: status
    end
  end
end
