class TreatmentWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{"#{ENV['queue_name']}"}, auto_delete: true

  def perform(_sqs_message, treatment_arm)
    begin
      treatment_arm = JSON.parse(treatment_arm).symbolize_keys!
      if(TreatmentArm.find(name: treatment_arm[:id], version: treatment_arm[:version])).blank?
        insert(treatment_arm)
      else
        Shoryuken.logger.info("TreatmentArm #{treatment_arm[:id]} version #{treatment_arm[:version]} exists already.  Skipping")
      end
    rescue => error
      Shoryuken.logger.error("Treatment Arm Worker failed with error #{error}")
    end
  end

  def insert(treatment_arm)
    begin
      treatment_arm_model = TreatmentArm.new
      treatment_arm_model.from_json(convert_model(treatment_arm).to_json)
      treatment_arm_model.save
      Shoryuken.logger.info("TreatmentArm #{treatment_arm[:id]} version #{treatment_arm[:version]} has been saved successfully")
    rescue => error
      Shoryuken.logger.error("Failed to save treatment arm with error #{error}")
    end
  end

  def convert_model(treatment_arm={})
    remove_blank_document({
        name: treatment_arm[:id],
        version: treatment_arm[:version],
        description: treatment_arm[:description],
        target_id: treatment_arm[:target_id],
        target_name: treatment_arm[:target_name],
        gene: treatment_arm[:gene],
        treatment_arm_status: treatment_arm[:treatment_arm_status],
        date_created: treatment_arm[:date_created].blank? ? DateTime.current.getutc().to_s : treatment_arm[:date_created],
        max_patients_allowed: treatment_arm[:max_patients_allowed],
        num_patients_assigned: treatment_arm[:num_patients_assigned],
        treatment_arm_drugs: treatment_arm[:treatment_arm_drugs],
        exclusion_criterias: treatment_arm[:exclusion_criterias],
        exclusion_diseases: treatment_arm[:exclusion_diseases],
        exclusion_drugs: treatment_arm[:exclusion_drugs],
        pten_results: treatment_arm[:pten_results],
        status_log: treatment_arm[:status_log],
        variant_report: treatment_arm[:variant_report]
    })
  end

  #Refacto!
  def remove_blank_document(treatment_arm)
    hash_proc = Proc.new { |k, v| v.kind_of?(Hash) ? (v.delete_if(&hash_proc); nil) : v.to_s.blank? }
    treatment_arm.delete_if(&hash_proc)
    if !treatment_arm[:exclusion_drugs].blank?
      treatment_arm[:exclusion_drugs].each do | drugs |
        drugs.delete_if(&hash_proc)
      end
    end
    treatment_arm
  end
end