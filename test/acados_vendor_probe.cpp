#include <gtest/gtest.h>

extern "C" {
#include "acados_c/ocp_nlp_interface.h"
}

TEST(AcadosVendorProbe, CreatesAndDestroysNlpPlan) {
    ocp_nlp_plan_t* plan = ocp_nlp_plan_create(1);
    ASSERT_NE(plan, nullptr);
    ocp_nlp_plan_destroy(plan);
}

TEST(AcadosVendorProbe, ExposesConfiguredQpSolverEnums) {
    const ocp_qp_solver_t osqp = PARTIAL_CONDENSING_OSQP;
    const ocp_qp_solver_t qpoases = FULL_CONDENSING_QPOASES;
    EXPECT_NE(osqp, INVALID_QP_SOLVER);
    EXPECT_NE(qpoases, INVALID_QP_SOLVER);
}

int main(int argc, char** argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
