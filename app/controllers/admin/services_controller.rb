# frozen_string_literal: true

module Admin
  class ServicesController < BaseController
    SERVICE_PAGE_SIZE = 10

    before_action :set_partner
    before_action :set_service, only: %i[update destroy tasks_panel]

    def index
      @query = params[:q].to_s.strip
      load_services
      @service = @partner.services.build

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append(
              'services_rows',
              partial: 'admin/services/service_row',
              collection: @services,
              as: :service,
              locals: { partner: @partner, query: @query, row_offset: @row_offset }
            ),
            turbo_stream.replace(
              'services_pagination',
              partial: 'admin/services/services_pagination',
              locals: { partner: @partner, query: @query, next_page: @next_page }
            )
          ]
        end
      end
    end

    def create
      @service = @partner.services.build(service_params)

      if @service.save
        redirect_to admin_partner_services_path(@partner), notice: 'Tạo gói dịch vụ thành công.'
      else
        load_services
        @open_service_modal = true
        flash.now[:alert] = @service.errors.full_messages

        respond_to do |format|
          format.html { render :index, status: :unprocessable_entity }
          format.turbo_stream { render_flash_turbo_stream(status: :unprocessable_entity) }
        end
      end
    end

    def update
      if @service.update(service_params)
        respond_to do |format|
          format.html { redirect_to admin_partner_services_path(@partner), notice: 'Cập nhật gói dịch vụ thành công.' }
          format.turbo_stream do
            @query = params[:q].to_s.strip
            load_services
            @service = @partner.services.build
            flash.now[:notice] = 'Cập nhật gói dịch vụ thành công.'
            render_services_turbo_stream
          end
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_partner_services_path(@partner), alert: @service.errors.full_messages }
          format.turbo_stream do
            error_message = @service.errors.full_messages
            @query = params[:q].to_s.strip
            load_services
            @service = @partner.services.build
            flash.now[:alert] = error_message
            render_services_turbo_stream(status: :unprocessable_entity)
          end
        end
      end
    end

    def destroy
      @service.destroy
      redirect_to admin_partner_services_path(@partner), notice: 'Xóa gói dịch vụ thành công.'
    end

    def tasks_panel
      return redirect_to(admin_partner_service_tasks_path(@partner, @service)) unless turbo_frame_request?

      @tasks = @service.tasks.order(created_at: :desc).includes(:member)
      @member_options = member_options
      @show_all_tasks = ActiveModel::Type::Boolean.new.cast(params[:show_all])

      render partial: 'admin/services/tasks_panel', locals: {
        partner: @partner,
        service: @service,
        tasks: @tasks,
        member_options: @member_options,
        edit_task: nil,
        show_all_tasks: @show_all_tasks
      }
    end

    private

    def set_partner
      @partner = Partner.find(params[:partner_id])
    end

    def set_service
      @service = @partner.services.find(params[:id])
    end

    def load_services
      services = @partner.services.order(:name, :id)
      if @query.present?
        services = services.where('name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
      end

      @page = [ params[:page].to_i, 1 ].max
      @row_offset = (@page - 1) * SERVICE_PAGE_SIZE
      @services = services.offset(@row_offset).limit(SERVICE_PAGE_SIZE).to_a
      @next_page = services.offset(@row_offset + SERVICE_PAGE_SIZE).limit(1).exists? ? @page + 1 : nil
    end

    def service_params
      params.expect(service: [ :name ])
    end

    def member_options
      User.member.order(created_at: :desc, id: :desc).map do |member|
        [ member.display_name, member.id ]
      end
    end

    def render_services_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace(
          'admin_services_page',
          partial: 'admin/services/page'
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
