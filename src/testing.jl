# Need to write `TestSetup.DF` (even if exported).
@testmodule TestSetup begin
    using Underemployment;
    const DS = data_settings(:default);
    const DF = load_data(data_fn(DS));
end

# --------------