cname = :default;
ds = data_settings(cname);

dfCps = load_data(data_fn(ds));

dfCps = prepare_data(ds);